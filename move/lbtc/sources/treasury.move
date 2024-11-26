// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A smart contract to manage the treasury and associated caps of a controlled coin.
///
/// Features:
/// - An admin can assign Minter and Pauser roles.
/// - Minter can mint tokens to specified addresses, respecting limits.
/// - Pauser can globally pause and unpause the coin.
/// - Admins manage permissions and ensure operational safety.
/// - Events track mint and burn operations.

/// This module handles the `TreasuryCap`
module lbtc::treasury;

use std::string::{Self, String};
use std::type_name;
use sui::bag::{Self, Bag};
use sui::coin::{Self, Coin, DenyCapV2, TreasuryCap};
use sui::deny_list::DenyList;
use sui::event;

/// The capability record does not exist.
const ENoAuthRecord: u64 = 0;
/// The limit for minting has been exceeded.
const EMintLimitExceeded: u64 = 1;
/// Trying to add a capability that already exists.
const ERecordExists: u64 = 2;
/// Trying to remove the last admin.
const EAdminsCantBeZero: u64 = 3;

// A structure that wraps the treasury cap of a coin and manages capabilities
// for granular and flexible policy control. Capabilities include:
// - `MinterCap` for controlled minting.
// - `PauserCap` for global pause/unpause.
// The structure uses `Bag` for dynamic field storage to assign roles dynamically.
public struct ControlledTreasury<phantom T> has key {
    id: UID,
    /// Number of currently active admins.
    /// Can't ever be zero, as the treasury would be locked.
    admin_count: u8,
    treasury_cap: TreasuryCap<T>,
    deny_cap: DenyCapV2<T>, // Retained for compatibility
    roles: Bag,
}

// === Roles / Capabilities ===

/// An administrator capability that can manage permissions for `ControlledTreasury`.
public struct AdminCap has store, drop {}

/// Define a mint capability that may mint coins, with a limit.
public struct MinterCap has store, drop {
    // TODO: Talk about this limit which could be best practice to enforce some check over
    // the amount of tokens that can be minted
    limit: u64,
    epoch: u64,
    left: u64,
}

/// A capability for enforcing global pause/unpause of the coin.
public struct PauserCap has store, drop {}

// === Events ===

public struct MintEvent<phantom T> has copy, drop {
    amount: u64,
    to: address,
}

public struct BurnEvent<phantom T> has copy, drop {
    amount: u64,
    from: address,
}

// === DF Keys ===

/// Namespace for dynamic fields: one for each of the capabilities.
public struct RoleKey<phantom T, phantom Cap> has copy, store, drop { owner: address }

// Note all "address" can represent multi-signature addresses and be authorized at any threshold

// === Capabilities ===

/// Create a new `AdminCap` to assign.
public(package) fun new_admin_cap(): AdminCap { AdminCap {} }

/// Create a new `MinterCap` to assign.
public(package) fun new_minter_cap(limit: u64, ctx: &TxContext): MinterCap {
    MinterCap {
        limit,
        epoch: ctx.epoch(),
        left: limit,
    }
}

/// Create a new `PauserCap` to assign.
public(package) fun new_pauser_cap(): PauserCap { PauserCap {} }

/// Create a new controlled treasury by wrapping the `TreasuryCap` of a coin.
/// The `ControlledTreasury` has to be shared after the creation.
public(package) fun new<T>(
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
public(package) fun deconstruct<T>(
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

/// Assigns a MinterCap to an address.
/// Safeguarded to only be callable by an AdminCap holder.
public fun assign_minter<T>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
    limit: u64,
    ctx: &mut TxContext,
) {
    // Ensure the sender has AdminCap
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);

    // Ensure the owner does not already have a MinterCap
    assert!(!treasury.has_cap<T, MinterCap>(owner), ERecordExists);

    // Create and add the MinterCap to the roles
    treasury.add_cap(owner, new_minter_cap(limit, ctx));
}

/// Assigns a PauserCap to an address.
/// Safeguarded to only be callable by an AdminCap holder.
#[allow(unused_mut_parameter)]
public(package) fun assign_pauser<T>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
    ctx: &mut TxContext,
) {
    // Ensure the sender has AdminCap
    assert!(treasury.has_cap<T, AdminCap>(ctx.sender()), ENoAuthRecord);

    // Ensure the owner does not already have a PauserCap
    assert!(!treasury.has_cap<T, PauserCap>(owner), ERecordExists);

    // Create and add the PauserCap to the roles
    add_cap(treasury, owner, new_pauser_cap());
}

/// Allow the admin to add capabilities to the treasury
/// Authorization checks that a capability under the given name is owned by the caller.
///
/// Aborts if:
/// - the sender does not have AdminCap
/// - the receiver already has a `C` cap
#[allow(unused_mut_parameter)]
public(package) fun add_capability<T, C: store + drop>(
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
public(package) fun remove_capability<T, C: store + drop>(
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

// === Mint operations ===

// Allow an authorized multi-sig to mint and transfer coins to a whitelisted address
///
/// Aborts if:
/// - sender does not have MinterCap assigned to them
/// - the amount is higher than the defined limit on MinterCap
///
/// Emits: MintEvent
public fun mint_and_transfer<T>(
    treasury: &mut ControlledTreasury<T>,
    amount: u64,
    to: address,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, MinterCap>(ctx.sender()), ENoAuthRecord);

    // get the MinterCap and check the limit; if a new epoch - reset it
    let MinterCap { limit, epoch, mut left } = get_cap_mut(treasury, ctx.sender());

    // reset the limit if a new epoch
    if (ctx.epoch() > *epoch) {
        left = limit;
        *epoch = ctx.epoch();
    };

    // Check that the amount is within the mint limit; update the limit
    assert!(amount <= *left, EMintLimitExceeded);
    *left = *left - amount;

    // Emit the event and mint + transfer the coins
    event::emit(MintEvent<T> { amount, to });
    let new_coin = coin::mint(&mut treasury.treasury_cap, amount, ctx);
    transfer::public_transfer(new_coin, to);
}

/// Allow any external address to burn coins.
///
/// Emits: BurnEvent
#[allow(unused_mut_parameter)]
public(package) fun burn<T>(
    treasury: &mut ControlledTreasury<T>,
    coin: Coin<T>,
    ctx: &mut TxContext,
) {
    // We can a special authorization check here before letting the sender burn their tokens

    event::emit(BurnEvent<T> {
        amount: coin::value<T>(&coin),
        from: ctx.sender(),
    });

    coin::burn(&mut treasury.treasury_cap, coin);
}

// === Pause operations ===

/// Enables the global pause for the coin.
/// Requires: `PauserCap`
/// Aborts if:
/// - Sender does not have the required `PauserCap`.
public fun enable_global_pause<T>(
    treasury: &mut ControlledTreasury<T>,
    deny_list: &mut DenyList,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, PauserCap>(ctx.sender()), ENoAuthRecord);

    coin::deny_list_v2_enable_global_pause(deny_list, &mut treasury.deny_cap, ctx);
}

/// Disables the global pause for the coin.
/// Requires the sender to have the `PauserCap` assigned.
public fun disable_global_pause<T>(
    treasury: &mut ControlledTreasury<T>,
    deny_list: &mut DenyList,
    ctx: &mut TxContext,
) {
    assert!(treasury.has_cap<T, PauserCap>(ctx.sender()), ENoAuthRecord);

    coin::deny_list_v2_disable_global_pause(deny_list, &mut treasury.deny_cap, ctx);
}

// === Utilities ===

/// Check if a capability `Cap` is assigned to the `owner`.
public fun has_cap<T, Cap: store>(
    treasury: &ControlledTreasury<T>,
    owner: address,
): bool {
    treasury.roles.contains(RoleKey<T, Cap> { owner })
}

/// Checks if global pause is enabled for the next epoch.
public fun is_global_pause_enabled<T>(deny_list: &DenyList): bool {
    coin::deny_list_v2_is_global_pause_enabled_next_epoch<T>(deny_list)
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
    treasury.roles.borrow(RoleKey<T, Cap> { owner })
}

/// Get a mutable ref to the capability for the `owner`.
fun get_cap_mut<T, Cap: store + drop>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
): &mut Cap {
    treasury.roles.borrow_mut(RoleKey<T, Cap> { owner })
}

/// Adds a capability `cap` for `owner`.
fun add_cap<T, Cap: store + drop>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
    cap: Cap,
) {
    treasury.roles.add(RoleKey<T, Cap> { owner }, cap)
}

/// Remove a `Cap` from the `owner`.
fun remove_cap<T, Cap: store + drop>(
    treasury: &mut ControlledTreasury<T>,
    owner: address,
): Cap {
    treasury.roles.remove(RoleKey<T, Cap> { owner })
}
