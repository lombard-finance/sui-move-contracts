#[test_only]
module lbtc::treasury_tests;

use lbtc::treasury::{Self, ControlledTreasury, AdminCap, MinterCap, PauserCap};
use std::string;
use sui::coin::{Self, Coin};
use sui::deny_list::{Self, DenyList};
use sui::test_scenario::{Self as ts, Scenario};
use sui::test_utils;
use lbtc::multisig_tests;

const TREASURY_ADMIN: address = @0x3;
const MINTER: address = @0x4;
const PAUSER: address = @0x5;
const USER: address = @0x6;
const MINT_LIMIT: u64 = 1_000_000;

public struct TREASURY_TESTS has drop {}

#[test]
fun test_global_pause_is_enabled_for_next_epoch() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury= create_test_currency(&mut ts);

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign PauserCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let pauser_cap = treasury::new_pauser_cap();
    treasury.add_capability<TREASURY_TESTS, PauserCap>(multisig_address, pauser_cap, ts.ctx());

    // Enable global pause
    ts.next_tx(multisig_address);
    let mut denylist: DenyList = ts.take_shared();
    treasury::enable_global_pause(&mut treasury, &mut denylist,  pks,
        weights,
        threshold,ts.ctx());

    // Ensure the global pause is active for next epoch
    ts.next_epoch(TREASURY_ADMIN);
    assert!(
        coin::deny_list_v2_is_global_pause_enabled_current_epoch<TREASURY_TESTS>(
            &denylist,
            ts.ctx()
        ),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test]
fun test_global_pause_is_disabled_for_next_epoch() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign PauserCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let pauser_cap = treasury::new_pauser_cap();
    treasury.add_capability<TREASURY_TESTS, PauserCap>(multisig_address, pauser_cap, ts.ctx());

    ts.next_tx(multisig_address);
    let mut denylist: DenyList = ts.take_shared();
    treasury::enable_global_pause(
      &mut treasury, 
      &mut denylist,
      pks,
      weights,
      threshold,
      ts.ctx()
    );

    // Disable global pause
    ts.next_tx(multisig_address);
    treasury::disable_global_pause(
      &mut treasury, 
      &mut denylist,
      pks,
      weights,
      threshold,
      ts.ctx()
    );

    // Ensure the global pause is inactive for next epoch
    ts.next_epoch(TREASURY_ADMIN);
    assert!(
        !coin::deny_list_v2_is_global_pause_enabled_current_epoch<TREASURY_TESTS>(
            &denylist,
            ts.ctx()
        ),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test]
fun test_mint_and_transfer_with_multisig_sender() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens using the multisig address
    ts.next_tx(multisig_address);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_and_transfer(
        &mut treasury,
        1000,
        USER,
        &denylist,
        pks,
        weights,
        threshold,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintLimitExceeded)]
fun test_mint_over_limit() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Attempt to mint more than the allowed limit
    ts.next_tx(multisig_address);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_and_transfer(
        &mut treasury,
        MINT_LIMIT + 1, // Exceeds the limit
        USER,
        &denylist,
        pks,
        weights,
        threshold,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoMultisigSender)]
fun test_minting_with_non_multisig_sender() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Assign MinterCap to TREASURY_ADMIN (a non-multisig address)
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN, minter_cap, ts.ctx());

    // Attempt to mint
    ts.next_tx(TREASURY_ADMIN);
    let denylist: DenyList = ts.take_shared();
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    treasury::mint_and_transfer(
        &mut treasury,
        1000,
        USER,
        &denylist,
        pks,
        weights,
        threshold,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintNotAllowed)]
fun test_cannot_mint_and_transfer_when_global_pause_enabled() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

   // Assign roles
    ts.next_tx(TREASURY_ADMIN);
    let pauser_cap = treasury::new_pauser_cap();
    treasury.add_capability<TREASURY_TESTS, PauserCap>(multisig_address, pauser_cap, ts.ctx());
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Enable global pause
    ts.next_tx(multisig_address);
    let mut denylist: DenyList = ts.take_shared();
    treasury::enable_global_pause(
      &mut treasury, 
      &mut denylist,
      pks,
      weights,
      threshold,
      ts.ctx()
    );

    ts.next_epoch(multisig_address);
    treasury::mint_and_transfer(
        &mut treasury,
        1000,
        USER,
        &denylist,
        pks,
        weights,
        threshold,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_unauthorized_global_pause() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Do NOT assign PauserCap to the multisig address

    // Attempt to enable global pause
    ts.next_tx(multisig_address);
    let mut denylist: DenyList = ts.take_shared();
    treasury::enable_global_pause(
        &mut treasury,
        &mut denylist,
        pks,
        weights,
        threshold,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

#[test]
fun test_multiple_roles_for_single_address() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Ensure the initial admin has an AdminCap
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury.has_cap<TREASURY_TESTS, AdminCap>(TREASURY_ADMIN));

    // Assign MinterCap to the same address
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN, minter_cap, ts.ctx());

    // Verify that the address has MinterCap
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury.has_cap<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN));

    // Assign PauserCap to the same address
    let pauser_cap = treasury::new_pauser_cap();
    treasury.add_capability<TREASURY_TESTS, PauserCap>(TREASURY_ADMIN, pauser_cap, ts.ctx());

    // Verify that the address has PauserCap
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury.has_cap<TREASURY_TESTS, PauserCap>(TREASURY_ADMIN));

    // Verify the address has all three roles
    let roles = treasury.list_roles<TREASURY_TESTS>(TREASURY_ADMIN);
    assert!(roles.contains(&string::utf8(b"AdminCap")));
    assert!(roles.contains(&string::utf8(b"MinterCap")));
    assert!(roles.contains(&string::utf8(b"PauserCap")));

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_unauthorized_role_assignment() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Attempt to assign MinterCap as USER (who is not an admin)
    ts.next_tx(USER);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(MINTER, minter_cap, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ERecordExists)]
fun test_duplicate_role_assignment() {
    let mut ts = ts::begin(TREASURY_ADMIN);

    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(MINTER, minter_cap, ts.ctx());

    // Attempt to assign MinterCap again to the same address
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(MINTER, minter_cap, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test]
fun test_role_removal() {
    let mut ts = ts::begin(TREASURY_ADMIN);

    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(MINTER, minter_cap, ts.ctx());

    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury.has_cap<TREASURY_TESTS, MinterCap>(MINTER));

    // Remove the MinterCap
    treasury.remove_capability<TREASURY_TESTS, MinterCap>(MINTER, ts.ctx());

    ts.next_tx(TREASURY_ADMIN);
    assert!(!treasury.has_cap<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN));

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EAdminsCantBeZero)]
fun test_cannot_remove_last_admin() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Attempt to remove AdminCap from TREASURY_ADMIN
    ts.next_tx(TREASURY_ADMIN);
    treasury.remove_capability<TREASURY_TESTS, AdminCap>(TREASURY_ADMIN, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test]
fun test_burn_coins() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens to USER
    ts.next_tx(multisig_address);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_and_transfer(
        &mut treasury,
        1000,
        USER,
        &denylist,
        pks,
        weights,
        threshold,
        ts.ctx(),
    );
    ts::return_shared(denylist);

    // USER burns the coins
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();
    treasury::burn(&mut treasury, coin, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test]
fun test_deconstruct_treasury() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    let (treasury_cap, deny_cap, roles) = treasury::deconstruct(treasury, ts.ctx());

    // Clean up
    test_utils::destroy(treasury_cap);
    test_utils::destroy(deny_cap);
    test_utils::destroy(roles);

    ts.end();
}

#[test_only]
public(package) fun create_test_currency(
    ts: &mut Scenario,
): ControlledTreasury<TREASURY_TESTS> {
    ts.next_tx(@0);
    deny_list::create_for_test(ts.ctx());

    ts.next_tx(TREASURY_ADMIN);
    let (treasury_cap, deny_cap, metadata) = coin::create_regulated_currency_v2(
        TREASURY_TESTS {},
        6,
        b"TESTCOIN",
        b"",
        b"",
        option::none(),
        true,
        ts.ctx(),
    );

    transfer::public_freeze_object(metadata);

    ts.next_tx(TREASURY_ADMIN);
    treasury::new<TREASURY_TESTS>(
        treasury_cap,
        deny_cap,
        TREASURY_ADMIN,
        ts.ctx(),
    )
}
