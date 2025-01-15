// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module manages the treasury and associated capabilities of a controlled, regulated coin.
///
/// ### Features:
/// - **Role-based Access Control**:
///   - `AdminCap`: Allows management of roles and permissions.
///   - `MinterCap`: Allows minting of coins within set limits.
///   - `PauserCap`: Allows pausing and unpausing all coin transactions globally.
/// - **Controlled Minting**:
///   - Mint operations are limited by `MinterCap` settings and can be dynamically
///     updated with epoch-specific limits.
/// - **Global Pause Mechanism**:
///   - Transactions can be globally paused and unpaused using the `PauserCap`.
/// - **Dynamic Field Storage**:
///   - Roles are stored dynamically in a `Bag` structure to support flexible role
///     assignment and management.
/// - **Event Tracking**:
///   - Emits events for mint and burn operations to provide transparency.

/// This module handles the `TreasuryCap`
module lbtc::treasury;

use lbtc::multisig;
use lbtc::bitcoin_utils::{get_output_type, get_dust_limit_for_output, get_unsupported_output_type};
use lbtc::pk_util;
use std::string::{Self, String};
use std::type_name;
use sui::bag::{Self, Bag};
use sui::coin::{Self, Coin, DenyCapV2, TreasuryCap};
use sui::deny_list::DenyList;
use sui::event;
use sui::bcs;
use sui::dynamic_field as df;
use sui::clock::Clock;
use consortium::consortium::{Self, Consortium};
use consortium::payload_decoder;

/// No authorization record exists for the action.
const ENoAuthRecord: u64 = 0;
/// Mint operation exceeds the allowed limit.
const EMintLimitExceeded: u64 = 1;
/// Attempt to assign a role that already exists.
const ERecordExists: u64 = 2;
/// At least one admin must exist.
const EAdminsCantBeZero: u64 = 3;
/// Mint operation attempted while global pause is enabled.
const EMintNotAllowed: u64 = 4;
// Sender is not a multisig address.
const ENoMultisigSender: u64 = 5;
// Mint amount cannot be zero.
const EMintAmountCannotBeZero: u64 = 6;
// Bascule check flag is not set.
const ENoBasculeCheck: u64 = 7;
// Invalid chain id in the payload.
const EInvalidChainId: u64 = 8;
// Recipient address cannot be zero.
const ERecipientZeroAddress: u64 = 9;
// Invalid action bytes in the payload.
const EInvalidActionBytes: u64 = 10;
// No action bytes set for the treasury.
const ENoActionBytes: u64 = 11;
// BTC public key unsupported.
const EScriptPubkeyUnsupported: u64 = 12;
// BTC withdrawal is disabled.
const EWithdrawalDisabled: u64 = 13;
// Amount is below the dust limit.
const EAmountBelowDustLimit: u64 = 14;
// Amount is less than the burn commission.
const EAmountLessThanBurnCommission: u64 = 15;
// Treasury address is not set.
const ENoTreasuryAddress: u64 = 16;
// Dust fee rate is not set.
const ENoDustFeeRate: u64 = 17;
// Burn commission is not set.
const ENoBurnCommission: u64 = 18;
// Withdrawal Flag is not set.
const ENoWithdrawalFlag: u64 = 19;
// Maximum fee is not set.
const ENoMaximumFee: u64 = 20;
// Fee approval has expired.
const EFeeApprovalExpired: u64 = 21;
// Fee is greater than amount.
const EFeeGreaterThanAmount: u64 = 22;

// Chain Id defined in the payload
const CHAIN_ID: u64 = 9; 

/// Represents a controlled treasury for managing a regulated coin.
public struct ControlledTreasury<phantom T> has key {
    id: UID, // Unique identifier for the treasury.
    admin_count: u8, // Number of active admins; must always be > 0.
    treasury_cap: TreasuryCap<T>, // Treasury cap for mint and burn operations.
    deny_cap: DenyCapV2<T>, // Deny list capability for regulating addresses.
    roles: Bag, // Dynamic storage for role assignments.
}

// === Roles / Capabilities ===

/// Allows management of roles and permissions for a `ControlledTreasury`.
public struct AdminCap has store, drop {}

/// Allows minting of coins with a specified limit and epoch tracking.
public struct MinterCap has store, drop {
    limit: u64, // Maximum number of coins that can be minted.
    epoch: u64, // Current epoch for minting limits.
    left: u64, // Remaining minting allowance in the current epoch.
}

/// Allows global pause and unpause of coin transactions.
public struct PauserCap has store, drop {}

/// Allows to set the mint fee for the autoclaim.
public struct OperatorCap has store, drop {}

// === Events ===

public struct MintEvent<phantom T> has copy, drop {
    amount: u64,
    to: address,
    tx_id: vector<u8>,
    index: u32,
}

public struct BurnEvent<phantom T> has copy, drop {
    amount: u64,
    from: address,
}

public struct UnstakeRequestEvent<phantom T> has copy, drop {
    from: address,
    script_pubkey:  vector<u8>,
    amount_after_fee: u64,
}

// === DF Keys ===

/// Namespace for dynamic fields: one for each of the capabilities.
public struct RoleKey<phantom T> has copy, store, drop { owner: address }

// Note all "address" can represent multi-signature addresses and be authorized at any threshold

// === Capabilities ===

/// Create a new `AdminCap` to assign.
public fun new_admin_cap(): AdminCap { AdminCap {} }

/// Create a new `MinterCap` to assign.
public fun new_minter_cap(limit: u64, ctx: &TxContext): MinterCap {
    assert!(limit > 0, EMintAmountCannotBeZero);
    MinterCap {
        limit,
        epoch: ctx.epoch(),
        left: limit,
    }
}

/// Create a new `PauserCap` to assign.
public fun new_pauser_cap(): PauserCap { PauserCap {} }

/// Create a new `OperatorCap` to assign.
public fun new_operator_cap(): OperatorCap { OperatorCap {} }

/// Creates a new controlled treasury by wrapping a `TreasuryCap` and `DenyCapV2`.
/// The treasury must be shared to allow usage across multiple transactions.
public fun new<T>(
    treasury_cap: TreasuryCap<T>,
    deny_cap: DenyCapV2<T>,
    owner: address,
    ctx: &mut TxContext,
): ControlledTreasury<T> {
    let mut treasury = ControlledTreasury {
        id: object::new(ctx),
        treasury_cap,
        deny_cap,
        admin_count: 1,
        roles: bag::new(ctx),
    };
    treasury.add_cap(owner, AdminCap {});
    treasury
}

#[lint_allow(share_owned)]
/// Make `ControlledTreasury` a shared object.
public fun share<T>(treasury: ControlledTreasury<T>) {
    transfer::share_object(treasury);
}

/// Unpack the `ControlledTreasury` and return the treasury cap, deny cap and the Bag.
/// The Bag must be cleared by the admin to be unpacked.
#[allow(unused_mut_parameter)]
public fun deconstruct<T>(
    treasury: ControlledTreasury<T>,
    ctx: &mut TxContext,
): (TreasuryCap<T>, DenyCapV2<T>, Bag) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);

    // Deconstruct the structure and return the parts
    let ControlledTreasury {
        id,
        admin_count: _,
        treasury_cap,
        deny_cap,
        roles,
    } = treasury;

    id.delete();

    (treasury_cap, deny_cap, roles)
}

// === Role (Cap) Management ===

/// Allow the admin to add capabilities to the treasury
/// Authorization checks that a capability under the given name is owned by the caller.
///
/// Aborts if:
/// - the sender does not have AdminCap
/// - the receiver already has a `C` cap
#[allow(unused_mut_parameter)]
public fun add_capability<T, C: store + drop>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
    cap: C,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    assert!(!treasury.has_cap<T, C>(owner), ERecordExists);

    // using a reflection trick to update admin count when adding a new admin
    if (type_name::get<C>() == type_name::get<AdminCap>()) {
        treasury.admin_count = treasury.admin_count + 1;
    };

    treasury.add_cap(owner, cap);
}

/// Allow the admin to remove capabilities from the treasury
/// Authorization checks that a capability under the given name is owned by the caller.
///
/// Aborts if:
/// - the sender does not have `AdminCap`
/// - the receiver does not have `C` cap
#[allow(unused_mut_parameter)]
public fun remove_capability<T, C: store + drop>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    assert!(treasury.has_cap<T, C>(owner), ENoAuthRecord);

    // using a reflection trick to update admin count when removing an admin
    // make sure there's at least one admin always
    if (type_name::get<C>() == type_name::get<AdminCap>()) {
        assert!(treasury.admin_count > 1, EAdminsCantBeZero);
        treasury.admin_count = treasury.admin_count - 1;
    };

    let _: C = treasury.remove_cap(owner);
}

// === Dynamic Field Operations ===
public fun toggle_bascule_check<T>(
   treasury: &mut ControlledTreasury<T>,
   ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    if (df::exists_(&treasury.id, b"bascule_check")) {
        let check = df::borrow_mut(&mut treasury.id, b"bascule_check");
        *check = !*check;
    } else {
        df::add(&mut treasury.id, b"bascule_check", true);
    };
}

public fun set_mint_action_bytes<T>(
    treasury: &mut ControlledTreasury<T>,
    mint_action_bytes: u32,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    if (df::exists_(&treasury.id, b"mint_action_bytes")) {
        let action = df::borrow_mut(&mut treasury.id, b"mint_action_bytes");
        *action = mint_action_bytes;
    } else {
        df::add(&mut treasury.id, b"mint_action_bytes", mint_action_bytes);
    };
}

public fun set_fee_action_bytes<T>(
    treasury: &mut ControlledTreasury<T>,
    fee_action_bytes: u32,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    if (df::exists_(&treasury.id, b"fee_action_bytes")) {
        let action = df::borrow_mut(&mut treasury.id, b"fee_action_bytes");
        *action = fee_action_bytes;
    } else {
        df::add(&mut treasury.id, b"fee_action_bytes", fee_action_bytes);
    };
}

public fun set_mint_fee<T>(
    treasury: &mut ControlledTreasury<T>,
    new_fee: u64,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, OperatorCap>(ctx.sender()), ENoAuthRecord);
    if (df::exists_(&treasury.id, b"maximum_fee")) {
        let fee = df::borrow_mut(&mut treasury.id, b"maximum_fee");
        *fee = new_fee;
    } else {
        df::add(&mut treasury.id, b"maximum_fee", new_fee);
    };
}

// === Mint operations ===

/// Mints and transfers coins to a specified address.
///
/// Aborts if:
/// - sender does not have MinterCap assigned to them
/// - sender is not a multisig address
/// - the amount is higher than the defined limit on MinterCap
/// - global pause is enabled
///
/// Emits: MintEvent
public fun mint_and_transfer<T>(
    treasury: &mut ControlledTreasury<T>,
    amount: u64,
    to: address,
    denylist: &DenyList,
    pks: vector<vector<u8>>,
    weights: vector<u8>,
    threshold: u16,
    tx_id: vector<u8>,
    index: u32,
    ctx: &mut TxContext,
) {
    // Check if the amount is greater than 0
    assert!(amount > 0, EMintAmountCannotBeZero);

    // Public key schema validation
    pk_util::validate_pks(&pks);

    // Ensure the sender is a valid multisig address
    assert!(
        multisig::is_sender_multisig(pks, weights, threshold, ctx),
        ENoMultisigSender,
    );

    // Ensure the sender is authorized with minter role
    assert!(treasury.has_cap<T, MinterCap>(ctx.sender()), ENoAuthRecord);

    // Ensure global pause is not enabled before continuing
    assert!(!is_global_pause_enabled<T>(denylist), EMintNotAllowed);

    // Get the MinterCap and check the limit; if a new epoch - reset it
    let MinterCap { limit, epoch, left } = get_cap_mut(treasury, ctx.sender());

    // Reset the limit if this is a new epoch
    if (ctx.epoch() > *epoch) {
        *left = *limit;
        *epoch = ctx.epoch();
    };

    // Check that the amount is within the mint limit; update the limit
    assert!(amount <= *left, EMintLimitExceeded);
    *left = *left - amount;

    // Emit the event and mint + transfer the coins
    event::emit(MintEvent<T> { amount, to, tx_id, index });
    let new_coin = coin::mint(&mut treasury.treasury_cap, amount, ctx);
    transfer::public_transfer(new_coin, to);
}

/// Mints and transfers coins to the address defined in the decoded payload.
/// The payload with the given proof is validated by the consortium before minting.
///
/// Aborts if:
/// - payload is not validated by the consortium
/// - global pause is enabled
///
/// Emits: MintEvent
public fun mint<T>(
    treasury: &mut ControlledTreasury<T>,
    consortium: &mut Consortium,
    denylist: &DenyList,
    //bascule: &mut Bascule,
    payload: vector<u8>,
    proof: vector<u8>,
    ctx: &mut TxContext,
) {
    // Ensure global pause is not enabled before continuing
    assert!(!is_global_pause_enabled<T>(denylist), EMintNotAllowed);
    // Validate the payload with consortium, if invalid, consortium will throw an error
    let validate_proof = consortium::validate_payload(consortium, payload, proof);

    let (action, to_chain, to, amount_u256, txid_u256, vout) = payload_decoder::decode_mint_payload(payload);

    // Convert the u256 to u64, if it's too large, the `Option` will be empty and extract will throw an error `EOPTION_NOT_SET`
    let amount = amount_u256.try_as_u64().extract();

    assert!(amount > 0, EMintAmountCannotBeZero);
    assert!(to != @0x0, ERecipientZeroAddress);
    assert!(to_chain.try_as_u64().extract() == CHAIN_ID, EInvalidChainId);
    assert!(action == treasury.get_mint_action_bytes(), EInvalidActionBytes);
    
    let tx_id = bcs::to_bytes(&txid_u256);
    let index = vout.try_as_u32().extract();
    
    // Validate with the bascule
    // if (treasury.is_bascule_check_enabled()) {
    //     bascule::validate_withdrawal(&mut bascule, tx_id, index: u32, to: address, amount: u64, ctx: &TxContext);
    // };

    // Resolve the proof to store the hash
    consortium::resolve_proof(consortium, validate_proof);

    // Emit the event and mint + transfer the coins
    event::emit(MintEvent<T> { amount, to, tx_id, index });
    let new_coin = coin::mint(&mut treasury.treasury_cap, amount, ctx);
    transfer::public_transfer(new_coin, to);
}

/// Mints and transfers coins to the address defined in the decoded payload.
/// The payload with the given proof is validated by the consortium before minting.
/// A fee payload is given which contains the fee approval signed by the user
public fun mint_with_fee<T>(
    treasury: &mut ControlledTreasury<T>,
    consortium: &mut Consortium,
    denylist: &DenyList,
    //bascule: &mut Bascule,
    mint_payload: vector<u8>,
    proof: vector<u8>,
    fee_payload: vector<u8>,
    user_signature: vector<u8>,
    user_public_key: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Ensure global pause is not enabled before continuing
    assert!(!is_global_pause_enabled<T>(denylist), EMintNotAllowed);
    // Validate the payload with consortium, if invalid, consortium will throw an error
    let validate_proof = consortium::validate_payload(consortium, mint_payload, proof);

    let (action, to_chain, to, amount_u256, txid_u256, vout) = payload_decoder::decode_mint_payload(mint_payload);

    // Convert the u256 to u64, if it's too large, the `Option` will be empty and extract will throw an error `EOPTION_NOT_SET`
    let amount = amount_u256.try_as_u64().extract();
    assert!(amount > 0, EMintAmountCannotBeZero);
    assert!(to != @0x0, ERecipientZeroAddress);
    assert!(to_chain.try_as_u64().extract() == CHAIN_ID, EInvalidChainId);
    assert!(action == treasury.get_mint_action_bytes(), EInvalidActionBytes);

    let tx_id = bcs::to_bytes(&txid_u256);
    let index = vout.try_as_u32().extract();
    
    // Validate the fee payload with the user signature
    pk_util::validate_signature(user_signature, user_public_key, &fee_payload);

    let (fee_action, fee_u256, expiry_u256) = payload_decoder::decode_fee_payload(fee_payload);
    let fee = fee_u256.try_as_u64().extract();
    let expiry = expiry_u256.try_as_u64().extract();
    assert!(fee_action == treasury.get_fee_action_bytes(), EInvalidActionBytes);
    assert!(fee < amount, EFeeGreaterThanAmount);
    // Expiry timestamp is in unix seconds, so we need to truncate the bottom 4 numbers from the clock timestamp.
    assert!(expiry > clock.timestamp_ms() / 1000, EFeeApprovalExpired);

    let mut mint_fee = treasury.get_mint_fee();
    if (mint_fee > fee) {
        mint_fee = fee;
    };
    let final_amount = amount - mint_fee;

    // Validate with the bascule
    // if (treasury.is_bascule_check_enabled()) {
    //     bascule::validate_withdrawal(&mut bascule, tx_id, index: u32, to: address, amount: u64, ctx: &TxContext);
    // };

    // Resolve the proof to store the hash
    consortium::resolve_proof(consortium, validate_proof);

    // Emit the event and mint + transfer the coins
    event::emit(MintEvent<T> { amount: final_amount, to, tx_id, index });
    let new_coin = coin::mint(&mut treasury.treasury_cap, final_amount, ctx);
    transfer::public_transfer(new_coin, to);
}

/// Allow any internal function to burn coins.
#[allow(unused_mut_parameter)]
public(package) fun burn_internal<T>(
    treasury: &mut ControlledTreasury<T>,
    coin: Coin<T>,
    _ctx: &mut TxContext,
) {
    coin::burn(&mut treasury.treasury_cap, coin);
}

/// Allow any external address to burn coins.
///
/// Emits: BurnEvent
#[allow(unused_mut_parameter)]
public fun burn<T>(
    treasury: &mut ControlledTreasury<T>,
    coin: Coin<T>,
    ctx: &mut TxContext,
) {
    event::emit(BurnEvent<T> {
        amount: coin::value<T>(&coin),
        from: ctx.sender(),
    });

    burn_internal(treasury, coin, ctx);
}

/// Allow any external address to redeem (burn) coins to initiate BTC withdrawal.
///
/// Emits: UnstakeRequest
#[allow(unused_mut_parameter)]
public fun redeem<T>(
    treasury: &mut ControlledTreasury<T>,
    mut coin: Coin<T>,
    script_pubkey: vector<u8>,
    ctx: &mut TxContext,
){
    // Determine the Bitcoin Address Output Type.
    let out_type = get_output_type(&script_pubkey);

    // Ensure the output type is supported.
    assert!(out_type != get_unsupported_output_type(), EScriptPubkeyUnsupported);

    // Verify that BTC withdrawal is enabled.
    assert!(is_withdrawal_enabled<T>(treasury), EWithdrawalDisabled);

    let burn_commission: u64 = get_burn_commission(treasury);

    let amount: u64 = coin::value<T>(&coin);

    // Ensure the amount is not less than the burn commission.
    assert!(amount > burn_commission, EAmountLessThanBurnCommission);

    // Calculate the amount remaining after deducting the burn commission.
    let amount_after_fee: u64 = amount - burn_commission;

    let dust_fee_rate: u64 = get_dust_fee_rate(treasury);

    // Calculate the dust limit using Bitcoin utilities.
    let dust_limit = get_dust_limit_for_output(
        out_type,
        &script_pubkey,
        dust_fee_rate,
    );

    // Ensure the amount after the fee meets the dust limit.
    assert!(amount_after_fee >= dust_limit, EAmountBelowDustLimit);

    // Check if the treasury address is defined. 
    let treasury_address: &address = get_treasury_address(treasury);
    
    // Transfer the burn commission to the treasury address.
    coin.split_and_transfer(burn_commission, *treasury_address, ctx);
        
    // Burn the remaining amount after the fee from the sender's account.
    burn_internal(treasury, coin, ctx);

    // Emit the `UnstakeRequest` event.
    event::emit(UnstakeRequestEvent<T> {
        from: ctx.sender(),
        script_pubkey,
        amount_after_fee: amount_after_fee,
    });
}

// === Pause operations ===

/// Enables the global pause for the coin.
/// Requires: `PauserCap`
///
/// Aborts if:
/// - Sender does not have the required `PauserCap`.
/// - Sender is not a valid multisig address.
public fun enable_global_pause<T>(
    treasury: &mut ControlledTreasury<T>,
    deny_list: &mut DenyList,
    pks: vector<vector<u8>>,
    weights: vector<u8>,
    threshold: u16,
    ctx: &mut TxContext,
) {
    // Public key schema validation
    pk_util::validate_pks(&pks);

    // Ensure the sender is a valid multisig address
    assert!(
        multisig::is_sender_multisig(pks, weights, threshold, ctx),
        ENoMultisigSender,
    );

    // Ensure the sender has PauserCap
    assert!(treasury.has_cap<T, PauserCap>(ctx.sender()), ENoAuthRecord);

    coin::deny_list_v2_enable_global_pause(deny_list, &mut treasury.deny_cap, ctx);
}

/// Disables the global pause for the coin.
/// Requires the sender to have the `PauserCap` assigned.
///
/// Aborts if:
/// - Sender does not have the required `PauserCap`.
/// - Sender is not a valid multisig address.
public fun disable_global_pause<T>(
    treasury: &mut ControlledTreasury<T>,
    deny_list: &mut DenyList,
    pks: vector<vector<u8>>,
    weights: vector<u8>,
    threshold: u16,
    ctx: &mut TxContext,
) {
    // Public key schema validation
    pk_util::validate_pks(&pks);

    // Ensure the sender is a valid multisig address
    assert!(
        multisig::is_sender_multisig(pks, weights, threshold, ctx),
        ENoMultisigSender,
    );

    // Ensure the sender has PauserCap
    assert!(treasury.has_cap<T, PauserCap>(ctx.sender()), ENoAuthRecord);

    coin::deny_list_v2_disable_global_pause(deny_list, &mut treasury.deny_cap, ctx);
}

// === Utilities ===

/// Set the value of `burn_commission`.
public fun set_burn_commission<T>(
    treasury: &mut ControlledTreasury<T>,
    new_burn_commission: u64,
    ctx: &mut TxContext
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    if (df::exists_(&treasury.id, b"burn_commission")) {
        let burn_commission = df::borrow_mut(&mut treasury.id, b"burn_commission");
        *burn_commission = new_burn_commission;
    } else {
        df::add(&mut treasury.id, b"burn_commission", new_burn_commission);
    };
}

/// Get the value of `burn_commission`.
public fun get_burn_commission<T>(
    treasury: &ControlledTreasury<T>,
): u64 {
    assert!(df::exists_(&treasury.id, b"burn_commission"), ENoBurnCommission );
    let burn_commission: &u64 = df::borrow(&treasury.id, b"burn_commission");
    *burn_commission
}

/// Set the value of `dust_fee_rate`.
public fun set_dust_fee_rate<T>(
    treasury: &mut ControlledTreasury<T>,
    new_dust_fee_rate: u64,
    ctx: &mut TxContext
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    if (df::exists_(&treasury.id, b"dust_fee_rate")) {
        let dust_fee_rate = df::borrow_mut(&mut treasury.id, b"dust_fee_rate");
        *dust_fee_rate = new_dust_fee_rate;
    } else {
        df::add(&mut treasury.id, b"dust_fee_rate", new_dust_fee_rate);
    };
}

/// Get the value of `dust_fee_rate`.
public fun get_dust_fee_rate<T>(
    treasury: &ControlledTreasury<T>,
): u64 {
    assert!(df::exists_(&treasury.id, b"dust_fee_rate"), ENoDustFeeRate );
    let dust_fee_rate: &u64 = df::borrow(&treasury.id, b"dust_fee_rate");
    *dust_fee_rate
}

/// Set the value of `dust_fee_rate`.
public fun set_treasury_address<T>(
    treasury: &mut ControlledTreasury<T>,
    new_treasury_address: address,
    ctx: &mut TxContext
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    if (df::exists_(&treasury.id, b"treasury_address")) {
        let treasury_address = df::borrow_mut(&mut treasury.id, b"treasury_address");
        *treasury_address = new_treasury_address;
    } else {
        df::add(&mut treasury.id, b"treasury_address", new_treasury_address);
    }; 
}

/// Set the value of `dust_fee_rate`.
public fun get_treasury_address<T>(
    treasury: &ControlledTreasury<T>
): &address {
    assert!(df::exists_(&treasury.id, b"treasury_address"), ENoTreasuryAddress );
    let treasury_address = df::borrow(&treasury.id, b"treasury_address");
    treasury_address
}

/// Check if `withdrawal_enabled` is enalbled.
public fun is_withdrawal_enabled<T>(
    treasury: &ControlledTreasury<T>,
): bool {
    assert!(df::exists_(&treasury.id, b"withdrawal_enabled"), ENoWithdrawalFlag );
    let withdrawal_enabled: &bool = df::borrow(&treasury.id, b"withdrawal_enabled");
    *withdrawal_enabled
}

/// Enable or Disable `withdrawal_enabled`.
public fun toggle_withdrawal<T>(
    treasury: &mut ControlledTreasury<T>,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);
    if (df::exists_(&treasury.id, b"withdrawal_enabled")) {
        let check = df::borrow_mut(&mut treasury.id, b"withdrawal_enabled");
        *check = !*check;
    } else {
        df::add(&mut treasury.id, b"withdrawal_enabled", true);
    };    
}

/// Check if a capability `Cap` is assigned to the `owner`.
public fun has_cap<T, Cap: store>(
    treasury: &ControlledTreasury<T>,
    owner: address,
): bool {
    treasury.roles.contains(RoleKey<Cap> { owner })
}

/// Checks if global pause is enabled for the next epoch.
public fun is_global_pause_enabled<T>(deny_list: &DenyList): bool {
    coin::deny_list_v2_is_global_pause_enabled_next_epoch<T>(deny_list)
}

/// Checks if bascule check is enabled.
public fun is_bascule_check_enabled<T>(
    treasury: &ControlledTreasury<T>,
): bool {
    assert!(df::exists_(&treasury.id, b"bascule_check"), ENoBasculeCheck);
    let check = df::borrow(&treasury.id, b"bascule_check");
    *check
}

/// Returns the mint action bytes for the treasury in u32.
public fun get_mint_action_bytes<T>(treasury: &ControlledTreasury<T>): u32 {
    assert!(df::exists_(&treasury.id, b"mint_action_bytes"), ENoActionBytes);
    let action = df::borrow(&treasury.id, b"mint_action_bytes");
    *action
}

/// Returns the fee action bytes for the treasury in u32.
public fun get_fee_action_bytes<T>(treasury: &ControlledTreasury<T>): u32 {
    assert!(df::exists_(&treasury.id, b"fee_action_bytes"), ENoActionBytes);
    let action = df::borrow(&treasury.id, b"fee_action_bytes");
    *action
}

/// Returns the mint fee for the autoclaim.
public fun get_mint_fee<T>(
    treasury: &ControlledTreasury<T>,
): u64 {
    assert!(df::exists_(&treasury.id, b"maximum_fee"), ENoMaximumFee);
    let fee = df::borrow(&treasury.id, b"maximum_fee");
    *fee
}

/// Returns a vector of role types assigned to the `owner`.
public fun list_roles<T>(
    treasury: &ControlledTreasury<T>,
    owner: address,
): vector<String> {
    let mut roles: vector<String> = vector::empty();
    if (has_cap<T, AdminCap>(treasury, owner)) {
        roles.push_back(string::utf8(b"AdminCap"));
    };
    if (has_cap<T, MinterCap>(treasury, owner)) {
        roles.push_back(string::utf8(b"MinterCap"));
    };
    if (has_cap<T, PauserCap>(treasury, owner)) {
        roles.push_back(string::utf8(b"PauserCap"));
    };

    roles
}

// === Private Utilities ===

#[allow(unused_function)]
/// Get a capability for the `owner`.
fun get_cap<T, Cap: store + drop>(
    treasury: &ControlledTreasury<T>,
    owner: address,
): &Cap {
    treasury.roles.borrow(RoleKey<Cap> { owner })
}

/// Get a mutable ref to the capability for the `owner`.
fun get_cap_mut<T, Cap: store + drop>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
): &mut Cap {
    treasury.roles.borrow_mut(RoleKey<Cap> { owner })
}

/// Adds a capability `cap` for `owner`.
fun add_cap<T, Cap: store + drop>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
    cap: Cap,
) {
    treasury.roles.add(RoleKey<Cap> { owner }, cap)
}

/// Remove a `Cap` from the `owner`.
fun remove_cap<T, Cap: store + drop>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
): Cap {
    treasury.roles.remove(RoleKey<Cap> { owner })
}
