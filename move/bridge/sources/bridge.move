module bridge::bridge;

use sui::coin::{Coin};
use sui::balance::{Self, Balance};
use sui::deny_list::DenyList;
use sui::event;
use sui::bag::{Self, Bag};
use lbtc::treasury::{Self, ControlledTreasury};

// Error when the vault balance is not enough to cover the native to wrapped token conversion
const EInsufficientBalance: u64 = 0;
// Error when trying to interact with a paused vault
const EVaultIsPaused: u64 = 1;
/// No authorization record exists for the action.
const ENoAuthRecord: u64 = 2;
/// Attempt to assign a role that already exists.
const ERecordExists: u64 = 3;

// Vault to store the wrapped token
public struct Vault<phantom WT> has key {
    id: UID,
    balance: Balance<WT>,
    is_paused: bool,
    roles: Bag, // Dynamic storage for role assignments.
}

// Admin capability to create the vault
public struct AdminCap has key, store {
    id: UID
}

/// Allows global pause and unpause of coin transactions.
public struct PauserCap has store, drop {}

/// Namespace for dynamic fields: one for each of the capabilities.
public struct RoleKey<phantom T> has copy, store, drop { owner: address }

// === Events ===
public struct WithdrawEvent<phantom WT> has copy, drop {
    amount: u64,
    address: address
}

public struct DepositEvent<phantom WT> has copy, drop {
    amount: u64,
    address: address
}

// Witness to mint the native token
public struct BridgeWitness has drop {} 

/// Create a new `PauserCap` to assign.
public fun new_pauser_cap(): PauserCap { PauserCap {} }

fun init(ctx: &mut TxContext) {
    let cap = AdminCap {
        id: object::new(ctx),
    };
    transfer::public_transfer(cap, ctx.sender());
}

// Initialize the vault with zero balance
// Only admin can call this function
public fun new_vault<WT>(_cap: &AdminCap, ctx: &mut TxContext) {
    let vault = Vault<WT> {
        id: object::new(ctx),
        balance: balance::zero<WT>(),
        is_paused: false,
        roles: bag::new(ctx),
    };
    transfer::share_object(vault);
}

/// Claim the native token by locking the wrapped token in the vault
/// Aborts if the vault is paused
public fun claim_native<WT, T>(
    coin: Coin<WT>,
    vault: &mut Vault<WT>,
    treasury: &mut ControlledTreasury<T>,
    denylist: &DenyList,
    ctx: &mut TxContext,
) {
    assert!(vault.is_paused == false, EVaultIsPaused);
    let witness = BridgeWitness {};
    let amount = coin.value();
    vault.balance.join(coin.into_balance());
    treasury::mint_with_witness(witness, treasury, amount, ctx.sender(), denylist, ctx);
    event::emit(WithdrawEvent<WT> { amount, address: ctx.sender() });
}

/// Burn the native token and get wrapped token in return
/// Aborts if the vault is paused
public fun return_native<T, WT>(
    coin: Coin<T>,
    vault: &mut Vault<WT>,
    treasury: &mut ControlledTreasury<T>,
    ctx: &mut TxContext,
): Coin<WT> {
    assert!(vault.is_paused == false, EVaultIsPaused);
    let amount= coin.value();
    assert!(vault.balance.value() >= amount, EInsufficientBalance);
    let coin_to_deposit = vault.balance.split(amount).into_coin(ctx);
    treasury::burn(treasury, coin, ctx);
    event::emit(DepositEvent<WT> { amount, address: ctx.sender() });
    coin_to_deposit
}

// === Admin operations ===

/// Allow the admin to add capabilities to the vaults
/// Authorization checks that a capability under the given name is owned by the caller.
///
/// Aborts if:
/// - the receiver already has a `C` cap
#[allow(unused_mut_parameter)]
public fun add_capability<WT, C: store + drop>(
    _admin_cap: &AdminCap,
    vault: &mut Vault<WT>,
    owner: address,
    cap: C,
) {
    assert!(!vault.has_cap<WT, C>(owner), ERecordExists);

    vault.add_cap(owner, cap);
}

/// Allow the admin to remove capabilities from the vault
/// Authorization checks that a capability under the given name is owned by the caller.
///
/// Aborts if:
/// - the receiver does not have `C` cap
#[allow(unused_mut_parameter)]
public fun remove_capability<WT, C: store + drop>(
    _cap: &AdminCap,
    vault: &mut Vault<WT>,
    owner: address,
) {
    assert!(vault.has_cap<WT, C>(owner), ENoAuthRecord);

    let _: C = vault.remove_cap(owner);
}

// === Pause operations ===

/// Enables the pause for the vault.
/// 
/// Aborts if sender does not have the `PauserCap`.
public fun enable_pause<WT>(vault: &mut Vault<WT>, ctx: &mut TxContext) {
    assert!(vault.has_cap<WT, PauserCap>(ctx.sender()), ENoAuthRecord);
    vault.is_paused = true;
}

/// Disables the pause for the vault.
/// 
/// Aborts if sender does not have the `PauserCap`.
public fun disable_pause<WT>(vault: &mut Vault<WT>, ctx: &mut TxContext) {
    assert!(vault.has_cap<WT, PauserCap>(ctx.sender()), ENoAuthRecord);
    vault.is_paused = false;
}

// Get the current state of the pause
public fun is_paused_enabled<WT>(vault: &Vault<WT>): bool {
    vault.is_paused
}

/// Check if a capability `Cap` is assigned to the `owner`.
public fun has_cap<WT, Cap: store>(
    vault: &Vault<WT>,
    owner: address,
): bool {
    vault.roles.contains(RoleKey<Cap> { owner })
}

// === Private functions ===

/// Adds a capability `cap` for `owner`.
fun add_cap<WT, Cap: store + drop>(
    vault: &mut Vault<WT>,
    owner: address,
    cap: Cap,
) {
    vault.roles.add(RoleKey<Cap> { owner }, cap)
}

/// Remove a `Cap` from the `owner`.
fun remove_cap<WT, Cap: store + drop>(
    vault: &mut Vault<WT>,
    owner: address,
): Cap {
    vault.roles.remove(RoleKey<Cap> { owner })
}

// === Testing ===
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun fill_vault<WT>(vault: &mut Vault<WT>, amount: Balance<WT>) {
    vault.balance.join(amount);
}
