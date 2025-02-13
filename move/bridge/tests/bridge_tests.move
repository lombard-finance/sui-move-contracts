#[test_only]
module bridge::bridge_tests;

use bridge::bridge::{Self, Vault, AdminCap, PauserCap, BridgeWitness};
use lbtc::treasury::{Self, ControlledTreasury};
use std::type_name;
use sui::coin::{Self, Coin};
use sui::balance;
use sui::deny_list::{Self, DenyList};
use sui::test_scenario::{Self as ts, Scenario};
use sui::test_utils;

const EWrongMintAmount: u64 = 0;
const EWrongPauseState: u64 = 1;

const TREASURY_ADMIN: address = @0x3;
const PAUSER: address = @0xFACE;
const MINT_LIMIT: u64 = 1000000;

public struct BRIDGE_TESTS has drop {}
public struct WTEST has drop {}

#[test]
fun test_claim_native() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Whitelist the witness
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<BridgeWitness>();
    treasury.add_witness_mint_capability<BRIDGE_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    // Claim the native token by locking the wrapped one
    ts.next_tx(TREASURY_ADMIN);
    let denylist: DenyList = ts.take_shared();
    let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
    let wrapped_coin = coin::mint_for_testing<WTEST>(1000, ts.ctx());
    bridge::claim_native<WTEST, BRIDGE_TESTS>(wrapped_coin, &mut vault, &mut treasury, &denylist, ts.ctx());

    ts.next_tx(TREASURY_ADMIN);
    let native_coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
    assert!(native_coin.value() == 1000, EWrongMintAmount);
    ts.return_to_sender(native_coin);
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared(vault);

    ts.end();
}

#[test]
fun test_return_native() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    
    // Fill the vault with the wrapped token
    ts.next_tx(TREASURY_ADMIN);
    let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
    bridge::fill_vault(&mut vault, balance::create_for_testing(1000));

    // Burn the native token to unlock the wrapped one
    ts.next_tx(TREASURY_ADMIN);
    let denylist: DenyList = ts.take_shared();
    let coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
    let wrapped_coin = bridge::return_native<BRIDGE_TESTS, WTEST>(coin, &mut vault, &mut treasury, ts.ctx());
    transfer::public_transfer(wrapped_coin, ts.ctx().sender());

    ts.next_tx(TREASURY_ADMIN);
    let wrapped_coin = ts.take_from_sender<Coin<WTEST>>();
    assert!(wrapped_coin.value() == 1000, EWrongMintAmount);
    ts.return_to_sender(wrapped_coin);
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared(vault);

    ts.end();
}

#[test]
fun test_enable_disable_pause() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    // Assign PauserCap
    ts.next_tx(TREASURY_ADMIN);
    let cap = ts.take_from_sender<AdminCap>();
    let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
    let pauser_cap = bridge::new_pauser_cap();
    bridge::add_capability(&cap, &mut vault, PAUSER, pauser_cap);
    ts.return_to_sender(cap);

    // Enable pause
    ts.next_tx(PAUSER);
    bridge::enable_pause(&mut vault, ts.ctx());
    assert!(vault.is_paused_enabled() == true, EWrongPauseState);

    // Disable pause
    ts.next_tx(PAUSER);
    bridge::disable_pause(&mut vault, ts.ctx());
    assert!(vault.is_paused_enabled() == false, EWrongPauseState);
    test_utils::destroy(treasury);
    ts::return_shared(vault);

    ts.end();
}

#[test, expected_failure(abort_code = bridge::EInsufficientBalance)]
fun test_insiffucient_vault_balance() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Burn the native token to unlock the wrapped one
    ts.next_tx(TREASURY_ADMIN);
    let denylist: DenyList = ts.take_shared();
    let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
    let coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
    let wrapped_coin = bridge::return_native<BRIDGE_TESTS, WTEST>(coin, &mut vault, &mut treasury, ts.ctx());
    transfer::public_transfer(wrapped_coin, ts.ctx().sender());

    ts.next_tx(TREASURY_ADMIN);
    let wrapped_coin = ts.take_from_sender<Coin<WTEST>>();
    assert!(wrapped_coin.value() == 1000, EWrongMintAmount);
    ts.return_to_sender(wrapped_coin);
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared(vault);

    ts.end();
}

#[test, expected_failure(abort_code = bridge::EZeroAmountCoin)]
fun test_return_zero_amount_coin() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    
    // Fill the vault with the wrapped token
    ts.next_tx(TREASURY_ADMIN);
    let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
    bridge::fill_vault(&mut vault, balance::create_for_testing(1000));

    // Burn the native token to unlock the wrapped one
    ts.next_tx(TREASURY_ADMIN);
    let denylist: DenyList = ts.take_shared();
    let mut coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
    let zero_coin = coin.split(0, ts.ctx());
    let wrapped_coin = bridge::return_native<BRIDGE_TESTS, WTEST>(zero_coin, &mut vault, &mut treasury, ts.ctx());
    transfer::public_transfer(wrapped_coin, ts.ctx().sender());
    ts.return_to_sender(coin);
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared(vault);

    ts.end();
}

#[test, expected_failure(abort_code = bridge::EVaultIsPaused)]
fun test_claim_when_pause_enabled() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Whitelist the witness
    ts.next_tx(TREASURY_ADMIN);
    let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<BridgeWitness>();
    treasury.add_witness_mint_capability<BRIDGE_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());
    let cap = ts.take_from_sender<AdminCap>();
    let pauser_cap = bridge::new_pauser_cap();
    bridge::add_capability(&cap, &mut vault, PAUSER, pauser_cap);
    ts.return_to_sender(cap);
    
    // enable pause
    ts.next_tx(PAUSER);
    bridge::enable_pause(&mut vault, ts.ctx());

    // Claim the native token by locking the wrapped one
    ts.next_tx(TREASURY_ADMIN);
    let denylist: DenyList = ts.take_shared();
    let wrapped_coin = coin::mint_for_testing<WTEST>(1000, ts.ctx());
    bridge::claim_native<WTEST, BRIDGE_TESTS>(wrapped_coin, &mut vault, &mut treasury, &denylist, ts.ctx());
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared(vault);

    ts.end();
}

#[test, expected_failure(abort_code = bridge::EVaultIsPaused)]
fun test_return_when_pause_enabled() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Fill the vault with the wrapped token
    ts.next_tx(TREASURY_ADMIN);
    let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
    let cap = ts.take_from_sender<AdminCap>();
    bridge::fill_vault(&mut vault, balance::create_for_testing(1000));
    let pauser_cap = bridge::new_pauser_cap();
    bridge::add_capability(&cap, &mut vault, PAUSER, pauser_cap);
    ts.return_to_sender(cap);
    
    // enable pause
    ts.next_tx(PAUSER);
    bridge::enable_pause(&mut vault, ts.ctx());

    // Burn the native token to unlock the wrapped one
    ts.next_tx(TREASURY_ADMIN);
    let denylist: DenyList = ts.take_shared();
    let coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
    let wrapped_coin = bridge::return_native<BRIDGE_TESTS, WTEST>(coin, &mut vault, &mut treasury, ts.ctx());
    transfer::public_transfer(wrapped_coin, ts.ctx().sender());
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared(vault);

    ts.end();
}

#[test, expected_failure(abort_code = bridge::ENoAuthRecord)]
fun test_enable_pause_no_auth() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    // Assign PauserCap
    ts.next_tx(TREASURY_ADMIN);
    let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
    let cap = ts.take_from_sender<AdminCap>();
    let pauser_cap = bridge::new_pauser_cap();
    bridge::add_capability(&cap, &mut vault, PAUSER, pauser_cap);
    ts.return_to_sender(cap);

    // Remove PauserCap
    ts.next_tx(TREASURY_ADMIN);
    let cap = ts.take_from_sender<AdminCap>();
    bridge::remove_capability<WTEST, BRIDGE_TESTS, PauserCap>(&cap, &mut vault, PAUSER);
    ts.return_to_sender(cap);

    // enable pause
    ts.next_tx(PAUSER);
    bridge::enable_pause(&mut vault, ts.ctx());

    test_utils::destroy(treasury);
    ts::return_shared(vault);

    ts.end();
}

#[test_only]
public(package) fun create_test_currency(
    ts: &mut Scenario,
): ControlledTreasury<BRIDGE_TESTS> {
    ts.next_tx(@0);
    deny_list::create_for_test(ts.ctx());

    ts.next_tx(TREASURY_ADMIN);
    let (mut treasury_cap, deny_cap, metadata) = coin::create_regulated_currency_v2(
        BRIDGE_TESTS {},
        6,
        b"TESTCOIN",
        b"",
        b"",
        option::none(),
        true,
        ts.ctx(),
    );
    let coin = coin::mint<BRIDGE_TESTS>(&mut treasury_cap, 1000, ts.ctx());
    transfer::public_transfer(coin, ts.ctx().sender());

    bridge::init_for_testing(ts.ctx());

    transfer::public_freeze_object(metadata);

    ts.next_tx(TREASURY_ADMIN);
    let treasury = treasury::new<BRIDGE_TESTS>(
        treasury_cap,
        deny_cap,
        TREASURY_ADMIN,
        ts.ctx(),
    );

    ts.next_tx(TREASURY_ADMIN);
    let cap = ts.take_from_sender<AdminCap>();
    bridge::new_vault<WTEST, BRIDGE_TESTS>(&cap, ts.ctx());
    ts.return_to_sender(cap);

    treasury
}


