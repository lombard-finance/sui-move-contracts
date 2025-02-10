module bridge::bridge;

use sui::coin::{Coin};
use sui::balance::{Self, Balance};
use sui::deny_list::DenyList;
use sui::event;
use lbtc::treasury::{Self, ControlledTreasury};

// Error when the vault balance is not enough to cover the native to wrapped token conversion
const EInsufficientBalance: u64 = 0;
// Error when trying to interact with a paused vault
const EVaultIsPaused: u64 = 1;

// Vault to store the wrapped token
public struct Vault<phantom WT> has key {
    id: UID,
    balance: Balance<WT>,
    is_paused: bool,
}

// Admin capability to create the vault
public struct AdminCap has key, store {
    id: UID
}

// === Events ===
public struct WithdrawEvent has copy, drop {
    amount: u64,
    address: address
}

public struct DepositEvent has copy, drop {
    amount: u64,
    address: address
}

// Witness to mint the native token
public struct BridgeWitness has drop {} 

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
    event::emit(WithdrawEvent { amount, address: ctx.sender() });
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
    event::emit(DepositEvent { amount, address: ctx.sender() });
    coin_to_deposit
}

// === Pause operations ===

/// Enables the pause for the vault.
/// Requires: `AdminCap`
public fun enable_pause<WT>(_cap: &AdminCap, vault: &mut Vault<WT>) {
    vault.is_paused = true;
}

/// Disables the pause for the vault.
/// Requires: `AdminCap`
public fun disable_pause<WT>(_cap: &AdminCap, vault: &mut Vault<WT>) {
    vault.is_paused = false;
}

// Get the current state of the pause
public fun is_paused_enabled<WT>(vault: &Vault<WT>): bool {
    vault.is_paused
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun fill_vault<WT>(vault: &mut Vault<WT>, amount: Balance<WT>) {
    vault.balance.join(amount);
}
