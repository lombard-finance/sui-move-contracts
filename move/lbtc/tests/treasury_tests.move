#[test_only]
module lbtc::treasury_tests;

use lbtc::treasury::{Self, ControlledTreasury, AdminCap, MinterCap, PauserCap, OperatorCap, ClaimerCap,
redeem, set_dust_fee_rate, set_burn_commission, set_treasury_address, toggle_withdrawal, get_witness_minter_cap_left, LBTCWitness};
use std::string;
use sui::coin::{Self, Coin};
use sui::deny_list::{Self, DenyList};
use sui::test_scenario::{Self as ts, Scenario};
use sui::test_utils;
use sui::clock;
use std::debug;
use lbtc::multisig_tests;
use std::vector;

const TREASURY_ADMIN: address = @0x3;
const MINTER: address = @0x4;
const USER: address = @0x6;
const MINT_LIMIT: u64 = 1_000_000;
const TXID: vector<u8> = b"abcd";
const IDX: u32 = 0;

const ETreasuryAddressDoesNotHaveOnlyFee: u64 = 1;

const OP_1: u8 = 0x51;
const OP_DATA_32: u8 = 0x20;

public struct TREASURY_TESTS has drop {}

public struct TestWitness has drop {}

public struct WrongTestWitness has drop {}

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

// === Deconstruct ===
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

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_deconstruct_aborts_when_sender_is_not_admin() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    ts.next_tx(USER);
    let (treasury_cap, deny_cap, roles) = treasury::deconstruct(treasury, ts.ctx());

    // Clean up
    test_utils::destroy(treasury_cap);
    test_utils::destroy(deny_cap);
    test_utils::destroy(roles);

    ts.end();
}

#[test]
fun test_enable_global_pause_for_next_epochs() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

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

    // Ensure the global pause is not active for the current epoch
    assert!(
        !coin::deny_list_v2_is_global_pause_enabled_current_epoch<TREASURY_TESTS>(
            &denylist,
            ts.ctx()
        ),
    );

    // Ensure the global pause is active in the next epoch
    ts.next_epoch(TREASURY_ADMIN);
    assert!(
        coin::deny_list_v2_is_global_pause_enabled_current_epoch<TREASURY_TESTS>(
            &denylist,
            ts.ctx()
        ),
    );

    // Ensure the global pause is active in the epoch after the next
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

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_enable_global_pause_aborts_when_does_not_have_role() {
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
fun test_disable_global_pause_for_next_epochs() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

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
    treasury::enable_global_pause(
      &mut treasury, 
      &mut denylist,
      pks,
      weights,
      threshold,
      ts.ctx()
    );

    // Ensure the global pause is active for next epoch
    ts.next_epoch(TREASURY_ADMIN);
    assert!(
        coin::deny_list_v2_is_global_pause_enabled_current_epoch<TREASURY_TESTS>(
            &denylist,
            ts.ctx()
        ),
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
fun test_enable_global_pause_v2_and_disable() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury= create_test_currency(&mut ts);

    // Assign PauserCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let pauser_cap = treasury::new_pauser_cap();
    treasury.add_capability<TREASURY_TESTS, PauserCap>(TREASURY_ADMIN, pauser_cap, ts.ctx());

    // Enable global pause v2
    ts.next_tx(TREASURY_ADMIN);
    let mut denylist: DenyList = ts.take_shared();
    treasury::enable_global_pause_v2(&mut treasury, &mut denylist, ts.ctx());

    // Ensure the global pause is active for next epoch
    ts.next_epoch(TREASURY_ADMIN);
    assert!(
        coin::deny_list_v2_is_global_pause_enabled_current_epoch<TREASURY_TESTS>(
            &denylist,
            ts.ctx()
        ),
    );

    // Disable global pause v2
    ts.next_tx(TREASURY_ADMIN);
    treasury::disable_global_pause_v2(&mut treasury, &mut denylist, ts.ctx());

    // Ensure the global pause is active for next epoch
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

// === Mint with witness ===
#[test]
fun test_mint_with_witness_successfull() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());
    assert!(treasury.witness_has_minter_cap<TREASURY_TESTS>(witness_type.into_string()));

    // Mint and transfer tokens using the multisig address
    ts.next_tx(USER);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_with_witness(
        TestWitness {},
        &mut treasury,
        MINT_LIMIT,
        USER,
        &denylist,
        ts.ctx(),
    );
    assert!(get_witness_minter_cap_left(&treasury, witness_type.into_string()) == 0);
    
    // User received the coin
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();
    assert!(coin.balance().value() == MINT_LIMIT);

    ts::return_to_address(USER, coin);
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

#[test]
fun test_mint_with_witness_in_different_epochs() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    // Mint and transfer tokens using the multisig address
    ts.next_tx(USER);
    let denylist: DenyList = ts.take_shared();
    // Mint coin1
    treasury::mint_with_witness(
        TestWitness {},
        &mut treasury,
        MINT_LIMIT - 1,
        USER,
        &denylist,
        ts.ctx(),
    );
    ts.next_epoch(USER);
    // Mint coin2
    treasury::mint_with_witness(
        TestWitness {},
        &mut treasury,
        2,
        USER,
        &denylist,
        ts.ctx(),
    );

    // Check remaining limit for this epoch
    assert!(get_witness_minter_cap_left(&treasury, witness_type.into_string()) == MINT_LIMIT - 2);

    // User balance
    // Get coin2 balance
    ts.next_tx(USER);
    let coin2: Coin<TREASURY_TESTS> = ts.take_from_sender();
    assert!(coin2.balance().value() == 2);

    // Get coin1 balance
    let coin1: Coin<TREASURY_TESTS> = ts.take_from_sender();
    assert!(coin1.balance().value() == MINT_LIMIT-1);

    ts::return_to_address(USER, coin1);
    ts::return_to_address(USER, coin2);
    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintLimitExceeded)]
fun test_mint_with_witness_aborts_when_exceed_limit() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    // Mint and transfer tokens using the multisig address
    ts.next_tx(USER);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_with_witness(
        TestWitness {},
        &mut treasury,
        MINT_LIMIT + 1,
        USER,
        &denylist,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintLimitExceeded)]
fun test_mint_with_witness_aborts_when_sum_exceed_limit() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    // Mint and transfer tokens using the multisig address
    ts.next_tx(USER);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_with_witness(
        TestWitness {},
        &mut treasury,
        MINT_LIMIT - 1,
        USER,
        &denylist,
        ts.ctx(),
    );
    // Check remaining limit for this epoch
    assert!(get_witness_minter_cap_left(&treasury, witness_type.into_string()) == 1);

    ts.next_tx(USER);
    treasury::mint_with_witness(
        TestWitness {},
        &mut treasury,
        2,
        USER,
        &denylist,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_mint_with_witness_aborts_when_witness_is_wrong() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);    
    
    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    // Mint and transfer tokens using the multisig address
    ts.next_tx(USER);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_with_witness(
        WrongTestWitness {},
        &mut treasury,
        1000,
        USER,
        &denylist,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintNotAllowed)]
fun test_mint_with_witness_aborts_when_global_pause_enabled() {
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
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

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

    ts.next_epoch(USER);
    treasury::mint_with_witness(
        TestWitness {},
        &mut treasury,
        MINT_LIMIT + 1,
        USER,
        &denylist,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintAmountCannotBeZero)]
fun test_mint_with_witness_aborts_when_amount_is_0() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    // Mint and transfer tokens using the multisig address
    ts.next_tx(USER);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_with_witness(
        TestWitness {},
        &mut treasury,
        0,
        USER,
        &denylist,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

// === Mint and transer by multisig ===
#[test]
fun test_mint_and_transfer_by_multisig_sender() {
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
        MINT_LIMIT,
        USER,
        &denylist,
        pks,
        weights,
        threshold,
        TXID,
        IDX,
        ts.ctx(),
    );

    ts.next_tx(USER);
    let coin = ts::take_from_address<Coin<TREASURY_TESTS>>(&mut ts, USER);
    let balance = coin::value(&coin);
    assert!(balance == MINT_LIMIT);

    ts::return_to_address(USER, coin);
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoMultisigSender)]
fun test_mint_and_transfer_aborsts_when_sender_is_not_multisig() {
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
        TXID,
        IDX,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_mint_and_transfer_aborts_when_does_not_have_mint_capability() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Mint and transfer tokens using the multisig address
    ts.next_tx(multisig_address);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_and_transfer(
        &mut treasury,
        MINT_LIMIT,
        USER,
        &denylist,
        pks,
        weights,
        threshold,
        TXID,
        IDX,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintNotAllowed)]
fun test_mint_and_transfer_aborts_when_global_pause_enabled() {
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
        TXID,
        IDX,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);

    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintLimitExceeded)]
fun test_mint_and_transfer_aborts_when_amount_greater_than_limit() {
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
        TXID,
        IDX,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts.end();
}

// === Capabilities add/remove ===
#[test]
fun test_add_capability_many_to_single_address() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Ensure the initial admin has an AdminCap
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury.has_cap<TREASURY_TESTS, AdminCap>(TREASURY_ADMIN));
    // Ensure there is no other roles assigned to the address
    let roles_before = treasury.list_roles<TREASURY_TESTS>(TREASURY_ADMIN);
    let roles_len_before = vector::length(&roles_before);
    assert!(roles_len_before == 1);

    // Assign MinterCap to the same address
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN, minter_cap, ts.ctx());
    assert!(treasury.has_cap<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN));

    // Assign PauserCap to the same address
    let pauser_cap = treasury::new_pauser_cap();
    treasury.add_capability<TREASURY_TESTS, PauserCap>(TREASURY_ADMIN, pauser_cap, ts.ctx());
    assert!(treasury.has_cap<TREASURY_TESTS, PauserCap>(TREASURY_ADMIN));

    // Verify the address has all three roles
    let roles_after = treasury.list_roles<TREASURY_TESTS>(TREASURY_ADMIN);
    let roles_len_after = vector::length(&roles_after);
    let mut i = 0;
    while (i < roles_len_after) {
        let str = vector::borrow(&roles_after, i);
        debug::print(str);
        i=i+1;
    };

    assert!(roles_len_after == 3);
    assert!(roles_after.contains(&string::utf8(b"AdminCap")));
    assert!(roles_after.contains(&string::utf8(b"MinterCap")));
    assert!(roles_after.contains(&string::utf8(b"PauserCap")));

    test_utils::destroy(treasury);
    ts.end();
}

#[test]
fun test_add_capability_to_different_addresses() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    // Assign themselves
    treasury.add_capability<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN, minter_cap, ts.ctx());
    assert!(treasury.has_cap<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN));

    // Assign admin capability to USER
    let admin_cap = treasury::new_admin_cap();
    treasury.add_capability<TREASURY_TESTS, AdminCap>(USER, admin_cap, ts.ctx());
    assert!(treasury.has_cap<TREASURY_TESTS, AdminCap>(USER));

    ts.next_tx(USER);
    // User can assign MinterCap to themselves
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(USER, minter_cap, ts.ctx());
    assert!(treasury.has_cap<TREASURY_TESTS, MinterCap>(USER));

    let roles_admin = treasury.list_roles<TREASURY_TESTS>(TREASURY_ADMIN);
    let roles_admin_len = vector::length(&roles_admin);
    let str = string::utf8(b"---Admin roles:");
    debug::print(&str);
    let mut i = 0;
    while (i < roles_admin_len) {
        let str = vector::borrow(&roles_admin, i);
        debug::print(str);
        i=i+1;
    };

    let roles_user = treasury.list_roles<TREASURY_TESTS>(USER);
    let roles_user_len = vector::length(&roles_user);
    let str = string::utf8(b"---User roles:");
    debug::print(&str);
    let mut i = 0;
    while (i < roles_user_len) {
        let str = vector::borrow(&roles_user, i);
        debug::print(str);
        i=i+1;
    };

    assert!(roles_admin_len == 2);
    assert!(roles_user_len == 2);
    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_add_capability_aborts_when_sender_is_not_admin() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Attempt to assign MinterCap as USER (who is not an admin)
    ts.next_tx(USER);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(MINTER, minter_cap, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EMintAmountCannotBeZero)]
fun test_new_minter_cap_aborts_when_mint_limit_is_0() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Attempt to create MinterCap with mint limit 0
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap_failed = treasury::new_minter_cap(0, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ERecordExists)]
fun test_add_capability_aborts_when_address_already_has_it() {
    let mut ts = ts::begin(TREASURY_ADMIN);

    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(MINTER, minter_cap, ts.ctx());

    // Attempt to assign MinterCap again to the same address
    let minter_cap = treasury::new_minter_cap(1001, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(MINTER, minter_cap, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test]
fun test_remove_capability_successfull() {
    let mut ts = ts::begin(TREASURY_ADMIN);

    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    let admin_cap = treasury::new_admin_cap();
    treasury.add_capability<TREASURY_TESTS, AdminCap>(USER, admin_cap, ts.ctx());
    assert!(treasury.has_cap<TREASURY_TESTS, AdminCap>(USER));

    // Remove the AdminCap from USER
    ts.next_tx(TREASURY_ADMIN);
    treasury.remove_capability<TREASURY_TESTS, AdminCap>(USER, ts.ctx());
    assert!(!treasury.has_cap<TREASURY_TESTS, AdminCap>(USER));

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::EAdminsCantBeZero)]
fun test_remove_capability_aborts_when_removes_the_last_admin() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Add AdminCap to USER +1
    ts.next_tx(TREASURY_ADMIN);
    let admin_cap = treasury::new_admin_cap();
    treasury.add_capability<TREASURY_TESTS, AdminCap>(USER, admin_cap, ts.ctx());
    assert!(treasury.has_cap<TREASURY_TESTS, AdminCap>(USER));

    // Remove AdminCap from TREASURY_ADMIN -1
    ts.next_tx(USER);
    treasury.remove_capability<TREASURY_TESTS, AdminCap>(TREASURY_ADMIN, ts.ctx());
    assert!(!treasury.has_cap<TREASURY_TESTS, AdminCap>(TREASURY_ADMIN));

    // Attempt to remove the last AdminCap
    ts.next_tx(USER);
    treasury.remove_capability<TREASURY_TESTS, AdminCap>(USER, ts.ctx());
    assert!(!treasury.has_cap<TREASURY_TESTS, AdminCap>(USER));

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_remove_capability_aborts_when_address_does_not_have_the_role() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Attempt to remove MinterCap from MINTER (who does not have it)
    ts.next_tx(TREASURY_ADMIN);
    treasury.remove_capability<TREASURY_TESTS, MinterCap>(MINTER, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_remove_capability_aborts_when_sender_is_not_admin() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN, minter_cap, ts.ctx());
    assert!(treasury.has_cap<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN));

    ts.next_tx(USER);
    treasury.remove_capability<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

// === Witness capabilities add/remove ===
#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_add_witness_mint_capability_aborts_when_sender_is_not_admin() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Attempt to assign MinterCap as USER (who is not an admin)
    ts.next_tx(USER);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ERecordExists)]
fun test_add_witness_mint_capability_aborts_when_address_already_has_the_role() {
    let mut ts = ts::begin(TREASURY_ADMIN);

    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    // Attempt to assign MinterCap again to the same address
    let minter_cap = treasury::new_minter_cap(1000, ts.ctx());
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test]
fun test_remove_witness_mint_capability_successfull() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());
    assert!(treasury.witness_has_minter_cap<TREASURY_TESTS>(witness_type.into_string()));

    // Remove the MinterCap from the witness
    treasury.remove_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), ts.ctx());
    assert!(!treasury.witness_has_minter_cap<TREASURY_TESTS>(witness_type.into_string()));

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = ::lbtc::treasury::ENoAuthRecord)]
fun test_remove_witness_mint_capability_aborts_when_sender_is_not_admin() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    let witness_type = type_name::get<TestWitness>();
    treasury.add_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), minter_cap, ts.ctx());
    assert!(treasury.witness_has_minter_cap<TREASURY_TESTS>(witness_type.into_string()));

    // Remove the MinterCap from the witness
    ts.next_tx(USER);
    treasury.remove_witness_mint_capability<TREASURY_TESTS>(witness_type.into_string(), ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

// === Burn ===
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
        TXID,
        IDX,
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

// === Redeem ===
#[test]
public fun test_redeem_success() {
    // Begin a new test scenario with TREASURY_ADMIN
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    
    ts.next_tx(TREASURY_ADMIN);
    // Set required dynamic fields:
    set_burn_commission<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    set_dust_fee_rate<TREASURY_TESTS>(&mut treasury, 3000, ts.ctx());
    set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx());

    assert!(treasury.is_withdrawal_enabled<TREASURY_TESTS>());

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens to the USER using the multisig address
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
        TXID,
        IDX,
        ts.ctx(),
    );
    ts::return_shared(denylist);

    // User redeems the coin
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();

    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());
    
    // Treasury receives the fee
    ts.next_tx(TREASURY_ADMIN);
    let fee: Coin<TREASURY_TESTS> = ts.take_from_sender();
    assert!(fee.balance().value() == 100, ETreasuryAddressDoesNotHaveOnlyFee);

    ts.return_to_sender(fee);
    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EScriptPubkeyUnsupported)]
public fun test_redeem_aborts_when_script_pubkey_is_invalid() {
    // Begin a new test scenario with TREASURY_ADMIN
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    // Set required dynamic fields:
    set_burn_commission<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    set_dust_fee_rate<TREASURY_TESTS>(&mut treasury, 3000, ts.ctx());
    set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens to the USER using the multisig address
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
        TXID,
        IDX,
        ts.ctx(),
    );
    ts::return_shared(denylist);

    // Now, attempt to redeem from USER with an unsupported scriptPubKey
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();

    // Create an unsupported scriptPubKey.
    let opcodes: vector<u8> = vector[OP_1]; // Missing OP_DATA_32 and full pubkey data
    let pubkey: vector<u8> = vector[2u8, 2u8]; // Too short to be a valid pubkey
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    // Attempt redeem with unsupported scriptPubKey, expecting failure
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());
    
    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EWithdrawalDisabled)]
public fun test_redeem_aborts_when_withdrawals_disabled() {
    // Setup
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Initially disabled by default. Temporarily enable, then disable again, to ensure it ends disabled.

    // Setup minimal fields for redeem:
    ts.next_tx(TREASURY_ADMIN);
    set_burn_commission<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    set_dust_fee_rate<TREASURY_TESTS>(&mut treasury, 3000, ts.ctx());
    set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx()); // Enable

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    ts.next_tx(TREASURY_ADMIN);
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx()); // Disable

    // Mint and transfer tokens to the USER using the multisig address
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
        TXID,
        IDX,
        ts.ctx(),
    );
    ts::return_shared(denylist);

    // Attempt to redeem
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();

    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    // This call fails with EWithdrawalDisabled
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EAmountLessThanBurnCommission)]
public fun test_redeem_aborts_when_amount_less_than_burn_comission() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Enable everything except we'll attempt to redeem an amount <= burn commission
    ts.next_tx(TREASURY_ADMIN);
    set_burn_commission<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    set_dust_fee_rate<TREASURY_TESTS>(&mut treasury, 3000, ts.ctx());
    set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx()); // Enable

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens to the USER using the multisig address
    ts.next_tx(multisig_address);
    let denylist: DenyList = ts.take_shared();
    treasury::mint_and_transfer(
        &mut treasury,
        50,
        USER,
        &denylist,
        pks,
        weights,
        threshold,
        TXID,
        IDX,
        ts.ctx(),
    );
    ts::return_shared(denylist);

    // Attempt to redeem 50, which is below burn_commission=100
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();

    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;
    // Fails with EAmountLessThanBurnCommission
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ENoBurnCommission)]
public fun test_redeem_aborts_when_burn_comission_is_not_set() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    // Notice we do NOT call set_burn_commission here
    set_dust_fee_rate<TREASURY_TESTS>(&mut treasury, 3000, ts.ctx());
    set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx());

    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens to the USER using the multisig address
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
        TXID,
        IDX,
        ts.ctx(),
    );
    ts::return_shared(denylist);
    // Attempt to redeem
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();

    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;
    // Fails with ENoBurnCommission since we never set it
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ENoDustFeeRate)]
public fun test_redeem_aborts_when_dust_fee_rate_is_not_set() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    set_burn_commission<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    // NOT call set_dust_fee_rate here
    set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx());

    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens to the USER using the multisig address
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
        TXID,
        IDX,
        ts.ctx(),
    );
    ts::return_shared(denylist);
    // Attempt to redeem
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();

    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;
    // Fails with ENoDustFeeRate because the dust fee rate is never defined
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ENoTreasuryAddress)]
public fun test_redeem_aborts_when_treasury_address_is_not_set() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    set_burn_commission<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    set_dust_fee_rate<TREASURY_TESTS>(&mut treasury, 3000, ts.ctx());
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx());
    // NOT call set_treasury_address

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens to the USER using the multisig address
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
        TXID,
        IDX,
        ts.ctx(),
    );
    ts::return_shared(denylist);
    // Attempt to redeem
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();

    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;
    // Fails with ENoTreasuryAddress because we never set it
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EAmountBelowDustLimit)]
public fun test_redeem_aborts_when_amount_below_dust_limit() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    set_burn_commission<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    // Use a high dust fee rate or a scriptPubKey that calculates a high dust limit
    set_dust_fee_rate<TREASURY_TESTS>(&mut treasury, 50_000, ts.ctx());
    set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());
    toggle_withdrawal<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();

    // Derive the multisig address
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign MinterCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let minter_cap = treasury::new_minter_cap(MINT_LIMIT, ts.ctx());
    treasury.add_capability<TREASURY_TESTS, MinterCap>(multisig_address, minter_cap, ts.ctx());

    // Mint and transfer tokens to the USER using the multisig address
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
        TXID,
        IDX,
        ts.ctx(),
    );
    ts::return_shared(denylist);

    // Attempt to redeem an amount so small that `amount_after_fee < dust_limit`
    ts.next_tx(USER);
    let coin: Coin<TREASURY_TESTS> = ts.take_from_sender();

    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;
    // amount = 120, burn_commission=100 => amount_after_fee=20 
    // dust_limit could easily exceed 20 with a high dust_fee_rate
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

// === V2 tests ===
use consortium::consortium::{Self, Consortium};
use bascule::bascule::{Self, Bascule, BasculeOwnerCap};
use std::type_name;


const EInvalidBasculeCheck: u64 = 1;
const EInvalidActionBytesCheck: u64 = 2;

const USER2: address = @0x0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc;

const INIT_VALSET: vector<u8> = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";

fun init_consortium(ts: &mut Scenario, init_valset: vector<u8>): Consortium {
    ts.next_tx(TREASURY_ADMIN);
    consortium::init_for_testing(ts.ctx());
    ts.next_tx(TREASURY_ADMIN);
    let mut consortium: Consortium = ts.take_shared();
    consortium::set_initial_validator_set(&mut consortium, init_valset, ts.ctx());
    consortium
}

fun init_bascule(ts: &mut Scenario): Bascule {
    ts.next_tx(TREASURY_ADMIN);
    bascule::test_init(ts.ctx());
    ts.next_tx(TREASURY_ADMIN);
    let mut bascule: Bascule = ts.take_shared();
    let witness_type = type_name::get<LBTCWitness>();
    let basculeOwnerCap : BasculeOwnerCap = ts.take_from_sender();
    bascule::add_withdrawal_validator(&basculeOwnerCap, &mut bascule, witness_type.into_string(), ts.ctx());
    bascule::update_validate_threshold(&basculeOwnerCap, &mut bascule, 200000000, ts.ctx());
    ts.return_to_sender(basculeOwnerCap);
    bascule
}

// === Mint aka manual claim ===
#[test]
fun test_mint_successfull() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000405b1e71e6cea98724038d2a7a63152c8b423b61908647fd7f4c803380b4fc653c5530ccca1c165dd6877d290a3ca90e30ee9048344fcb63ad52cd4b9bcfa41698";

    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Anyone can call mint with the right payload and proof
    ts.next_tx(USER);
    treasury::mint_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        ts.ctx(),
    );

    // User from the payload recieves the coins
    ts.next_tx(USER2);
    let coin: Coin<TREASURY_TESTS> = ts::take_from_sender(&mut ts);
    let balance = coin::value(&coin);
    debug::print(&balance);
    assert!(balance == 100000000);
    ts::return_to_sender(&mut ts, coin);
    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EUsedPayload)]
fun test_mint_aborts_when_payload_has_been_used() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000405b1e71e6cea98724038d2a7a63152c8b423b61908647fd7f4c803380b4fc653c5530ccca1c165dd6877d290a3ca90e30ee9048344fcb63ad52cd4b9bcfa41698";

    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Mint and transfer tokens
    ts.next_tx(USER2);
    treasury::mint_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        ts.ctx(),
    );

    ts.next_tx(TREASURY_ADMIN);
    treasury::mint_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);

    ts.end();
}

#[test, expected_failure(abort_code = bascule::EWithdrawalFailedValidation)]
fun test_mint_aborts_when_amount_exceeds_bascule_threshold() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    // Init bascule with a lower threshold
    bascule::test_init(ts.ctx());
    ts.next_tx(TREASURY_ADMIN);
    let mut bascule: Bascule = ts.take_shared();
    let witness_type = type_name::get<LBTCWitness>();
    let basculeOwnerCap : BasculeOwnerCap = ts.take_from_sender();
    bascule::add_withdrawal_validator(&basculeOwnerCap, &mut bascule, witness_type.into_string(), ts.ctx());
    bascule::update_validate_threshold(&basculeOwnerCap, &mut bascule, 10000000, ts.ctx());
    ts.return_to_sender(basculeOwnerCap);

    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000405b1e71e6cea98724038d2a7a63152c8b423b61908647fd7f4c803380b4fc653c5530ccca1c165dd6877d290a3ca90e30ee9048344fcb63ad52cd4b9bcfa41698";

    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Anyone can call mint with the right payload and proof
    ts.next_tx(USER);
    treasury::mint_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        ts.ctx(),
    );


    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EMintNotAllowed)]
fun test_mint_aborts_when_global_pause_enabled() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let mut denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000405b1e71e6cea98724038d2a7a63152c8b423b61908647fd7f4c803380b4fc653c5530ccca1c165dd6877d290a3ca90e30ee9048344fcb63ad52cd4b9bcfa41698";

    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign PauserCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let pauser_cap = treasury::new_pauser_cap();
    treasury.add_capability<TREASURY_TESTS, PauserCap>(multisig_address, pauser_cap, ts.ctx());

    // Enable global pause
    ts.next_tx(multisig_address);
    treasury::enable_global_pause(&mut treasury, &mut denylist,  pks, weights, threshold,ts.ctx());

    // Anyone can call mint with the right payload and proof
    ts.next_tx(USER);
    treasury::mint_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);

    ts.end();
}

// === Manual mint invalid parameters ===
const INIT_VALSET_WRONG_PAYLOAD: vector<u8> = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";

fun init_and_mint(payload: vector<u8>, proof: vector<u8>) {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET_WRONG_PAYLOAD);
    let mut bascule: Bascule = init_bascule(&mut ts);

    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Mint and transfer tokens using the multisig address
    ts.next_tx(USER2);
    treasury::mint_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);

    ts.end();
}

#[test, expected_failure(abort_code = treasury::ERecipientZeroAddress)]
fun test_mint_aborts_when_recipient_zero_address() {
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004085977372f875bbf798ec51fa03343111c3ed386166c4e4f3418d7f6f725c8c794504928541c4275008a08791041237507ab5892466e5f88c5810a273bc857cf60000000000000000000000000000000000000000000000000000000000000040ca1f211a20d7d450ab734ef9bf2519fe45773dd28578d5b32056fe57c4acdb65365b087d7fa9fd31d974d909d3f9ffddb5f0de9f87e0fbcc3245ca464e8d8a80";

    init_and_mint(payload, proof);
}

#[test, expected_failure(abort_code = consortium::EInvalidPayload)]
fun test_mint_aborts_when_recipient_different_address() {
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000000f90793a54e809bf708bd0fbcc63d311e3bb1be10000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004085977372f875bbf798ec51fa03343111c3ed386166c4e4f3418d7f6f725c8c794504928541c4275008a08791041237507ab5892466e5f88c5810a273bc857cf60000000000000000000000000000000000000000000000000000000000000040ca1f211a20d7d450ab734ef9bf2519fe45773dd28578d5b32056fe57c4acdb65365b087d7fa9fd31d974d909d3f9ffddb5f0de9f87e0fbcc3245ca464e8d8a80";

    init_and_mint(payload, proof);
}

#[test, expected_failure(abort_code = treasury::EMintAmountCannotBeZero)]
fun test_mint_aborts_when_amount_zero() {
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004067197da5e3f02a014fefadcac84d3974ecd2909b0b3ef07b52950402f2849987116d4b5ca1f70668c934763d9a73419001a0bd2c0a12dd31efc37e72253eaa0f000000000000000000000000000000000000000000000000000000000000004020f955183d71fd589d192f05c72d501d471cdd750ba816b4a7b87715c735e7b750d6d13314f705704653808cdeedb5a4b644fed455383dc9ae16b1780edaf092";

    init_and_mint(payload, proof);
}

#[test, expected_failure(abort_code = consortium::EInvalidPayload)]
fun test_mint_aborts_when_amount_is_different() {
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004067197da5e3f02a014fefadcac84d3974ecd2909b0b3ef07b52950402f2849987116d4b5ca1f70668c934763d9a73419001a0bd2c0a12dd31efc37e72253eaa0f000000000000000000000000000000000000000000000000000000000000004020f955183d71fd589d192f05c72d501d471cdd750ba816b4a7b87715c735e7b750d6d13314f705704653808cdeedb5a4b644fed455383dc9ae16b1780edaf092";

    init_and_mint(payload, proof);
}

#[test, expected_failure(abort_code = treasury::EInvalidActionBytes)]
fun test_mint_aborts_when_action_bytes_are_unknown() {
    let payload: vector<u8> = x"c2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000040ca8c27b19ee29bcdfe79f04e74b24a3514112d468dd8c77a97c411f0ff8696e853563a2f25a2639789ea69b999711e54c1e85e0918b90c74a232ee415b870a06000000000000000000000000000000000000000000000000000000000000004046583ab2a3740a776b90ce393e1d89e2e79096755812d3d650198e8a14a2edff7c83a01c1891ee53e2f3cf660594857c6fbce4d0cbd753c9cd51b3ddc80e15bf";

    init_and_mint(payload, proof);
}

#[test, expected_failure(abort_code = treasury::EInvalidChainId)]
fun test_mint_aborts_when_chain_id_is_different() {
    let payload: vector<u8> = x"f2e73f7c0200000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004084e21bfba72ed78acaff8f5d45aaa5f8f5829b37981bd22c6bdc90c65506d4d13bd8cc29a4594d19119120af16c731e41f98f1b4363c748556c5ce825382873d0000000000000000000000000000000000000000000000000000000000000040233ebf085e798413129ffc1850d0a7b3c45a2fe61cfb52869fb5fc7f7b578e471b5f9b8842c1574d5e2100b7d465d67a6e4c69d70400f226b86ea5a1de56ae59";

    init_and_mint(payload, proof);
}

#[test, expected_failure(abort_code = consortium::EInvalidPayload)]
fun test_mint_aborts_when_txid_is_wrong() {
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004084e21bfba72ed78acaff8f5d45aaa5f8f5829b37981bd22c6bdc90c65506d4d13bd8cc29a4594d19119120af16c731e41f98f1b4363c748556c5ce825382873d0000000000000000000000000000000000000000000000000000000000000040233ebf085e798413129ffc1850d0a7b3c45a2fe61cfb52869fb5fc7f7b578e471b5f9b8842c1574d5e2100b7d465d67a6e4c69d70400f226b86ea5a1de56ae59";

    init_and_mint(payload, proof);
}

#[test, expected_failure(abort_code = consortium::EInvalidPayload)]
fun test_mint_aborts_when_vout_is_wrong() {
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004084e21bfba72ed78acaff8f5d45aaa5f8f5829b37981bd22c6bdc90c65506d4d13bd8cc29a4594d19119120af16c731e41f98f1b4363c748556c5ce825382873d0000000000000000000000000000000000000000000000000000000000000040233ebf085e798413129ffc1850d0a7b3c45a2fe61cfb52869fb5fc7f7b578e471b5f9b8842c1574d5e2100b7d465d67a6e4c69d70400f226b86ea5a1de56ae59";

    init_and_mint(payload, proof);
}

// === Mint with fee aka autoclaim ===
const USER3: address = @0x00101fde830a55138f976efefdb0c812071efa9cc3dc4657ab605ccab7af7e96;
const USER4: address = @0x8b7eb1112b07c9d18dde43c2d85d7044049f741936d198c78d7e860595037e28;
const AUTOCLAIMER: address = @0x8;

#[test]
fun test_autoclaim() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let fee_payload: vector<u8> = x"04acbbb20100000000000000000000000000000000000000000000000000000035834a8abfde966bacd4260852155f7b523ef157f0b75a0e1e8a0784e463c3ef0bb69deb000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000ffffffff";

    let payload_ed25519: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a00101fde830a55138f976efefdb0c812071efa9cc3dc4657ab605ccab7af7e960000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof_ed25519: vector<u8> = x"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040a8f2bfcac5f4a32ac79edcc801408c5b86dabc8a8e74e2116c11d96cfb73c5bb72339db14feb704222958304002f9e3582e4a533067f188d18988a05819e6696";
    let user_signature_ed25519: vector<u8> = x"34bf3d641436c0ac35fb3d5460dac2b9cc3c4b6c6bb9ce3ffebd3c3c187f9b921b745d2b5e3b6882e2f7225c8ffd505f829be22116896aea4ecb9a76f894cd0b";
    let user_pubkey_ed25519: vector<u8> = x"00661ca05b19191eabfd7b55421f8017fbcb251cc2a1e3aa07a1aaf9841d0bc3e3";

    let payload_secp256k1: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a8b7eb1112b07c9d18dde43c2d85d7044049f741936d198c78d7e860595037e280000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"; 
    let proof_secp256k1: vector<u8> = x"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040feef3518490db7c90363fa3238a57e7c6ec6d441262dff452d04eeefb01d76e56f4d74aef9519ec431d167525609ee71f092fcb96b4dbf5c04d075a2c5a9300f";
    let user_signature_secp256k1: vector<u8> = x"5295124e3f260c88b2e298dded80e944c8a479b84ec960c385c7edfecc07c54b0e9c048a0f2fc193960dd88a1595b7c87a5359e5c6d624d042e8bd8ec845b3b9";
    let user_pubkey_secp256k1: vector<u8> = x"0103bdffbd040f50b80332c585d74552d97344badaca0cb25fe4cf8f0ce15a908bdb";
    
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_fee_action_bytes<TREASURY_TESTS>(&mut treasury, 78429106, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_package_id<TREASURY_TESTS>(&mut treasury, @0xbfde966bacd4260852155f7b523ef157f0b75a0e1e8a0784e463c3ef0bb69deb, ts.ctx());
    treasury::set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());


    // Set mint fee
    let operator_cap = treasury::new_operator_cap();
    treasury.add_capability<TREASURY_TESTS, OperatorCap>(TREASURY_ADMIN, operator_cap, ts.ctx());
    treasury::set_mint_fee<TREASURY_TESTS>(&mut treasury, 2, ts.ctx());
    
    // Assign ClaimerCap to AUTOCLAIMER
    let claimer_cap = treasury::new_claimer_cap();
    treasury.add_capability<TREASURY_TESTS, ClaimerCap>(AUTOCLAIMER, claimer_cap, ts.ctx());

    let mut clock = clock::create_for_testing(ts.ctx());
    clock.set_for_testing(1736941840000);
    
    // Mint and transfer tokens
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload_ed25519,
        proof_ed25519,
        fee_payload,
        user_signature_ed25519,
        user_pubkey_ed25519,
        &clock,
        ts.ctx(),
    );

    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload_secp256k1,
        proof_secp256k1,
        fee_payload,
        user_signature_secp256k1,
        user_pubkey_secp256k1,
        &clock,
        ts.ctx(),
    );

    // User from the payload recieves the coins
    ts.next_tx(USER3);
    let coin: Coin<TREASURY_TESTS> = ts::take_from_sender(&mut ts);
    let balance = coin::value(&coin);
    debug::print(&balance);
    assert!(balance == 100000000 - 2);
    ts::return_to_sender(&mut ts, coin);

    // User from the payload recieves the coins
    ts.next_tx(USER4);
    let coin: Coin<TREASURY_TESTS> = ts::take_from_sender(&mut ts);
    let balance = coin::value(&coin);
    debug::print(&balance);
    assert!(balance == 100000000 - 2);
    ts::return_to_sender(&mut ts, coin);

    //Treasury receives the fee
    ts.next_tx(TREASURY_ADMIN);
    let fee: Coin<TREASURY_TESTS> = ts.take_from_sender();
    debug::print(&fee.balance().value());
    assert!(fee.balance().value() == 2, ETreasuryAddressDoesNotHaveOnlyFee);
    ts.return_to_sender(fee);

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);
    clock.destroy_for_testing();

    ts.end();
}

#[test]
fun test_mint_with_fee_takes_min_fee_from_contract_and_permit() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a00101fde830a55138f976efefdb0c812071efa9cc3dc4657ab605ccab7af7e960000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040a8f2bfcac5f4a32ac79edcc801408c5b86dabc8a8e74e2116c11d96cfb73c5bb72339db14feb704222958304002f9e3582e4a533067f188d18988a05819e6696";

    let fee_payload: vector<u8> = x"04acbbb20100000000000000000000000000000000000000000000000000000035834a8abfde966bacd4260852155f7b523ef157f0b75a0e1e8a0784e463c3ef0bb69deb000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000ffffffff";
    let user_signature: vector<u8> = x"34bf3d641436c0ac35fb3d5460dac2b9cc3c4b6c6bb9ce3ffebd3c3c187f9b921b745d2b5e3b6882e2f7225c8ffd505f829be22116896aea4ecb9a76f894cd0b";
    let user_pubkey: vector<u8> = x"00661ca05b19191eabfd7b55421f8017fbcb251cc2a1e3aa07a1aaf9841d0bc3e3";
    
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_fee_action_bytes<TREASURY_TESTS>(&mut treasury, 78429106, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_package_id<TREASURY_TESTS>(&mut treasury, @0xbfde966bacd4260852155f7b523ef157f0b75a0e1e8a0784e463c3ef0bb69deb, ts.ctx());
    treasury::set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());

    // Set mint fee much higher than the fee limit in the permit
    let operator_cap = treasury::new_operator_cap();
    treasury.add_capability<TREASURY_TESTS, OperatorCap>(TREASURY_ADMIN, operator_cap, ts.ctx());
    treasury::set_mint_fee<TREASURY_TESTS>(&mut treasury, 200000000, ts.ctx());
    
    // Assign ClaimerCap to AUTOCLAIMER
    let claimer_cap = treasury::new_claimer_cap();
    treasury.add_capability<TREASURY_TESTS, ClaimerCap>(AUTOCLAIMER, claimer_cap, ts.ctx());

    let mut clock = clock::create_for_testing(ts.ctx());
    clock.set_for_testing(1736941840000);
    
    // Mint and transfer tokens
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        fee_payload,
        user_signature,
        user_pubkey,
        &clock,
        ts.ctx(),
    );

    // User from the payload recieves the coins
    ts.next_tx(USER3);
    let coin: Coin<TREASURY_TESTS> = ts::take_from_sender(&mut ts);
    let balance = coin::value(&coin);
    debug::print(&balance);
    assert!(balance == 100000000 - 3);
    ts::return_to_sender(&mut ts, coin);

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);
    clock.destroy_for_testing();

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EUsedPayload)]
fun test_mint_with_fee_aborts_when_payload_has_been_used() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a00101fde830a55138f976efefdb0c812071efa9cc3dc4657ab605ccab7af7e960000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040a8f2bfcac5f4a32ac79edcc801408c5b86dabc8a8e74e2116c11d96cfb73c5bb72339db14feb704222958304002f9e3582e4a533067f188d18988a05819e6696";

    let fee_payload: vector<u8> = x"04acbbb20100000000000000000000000000000000000000000000000000000035834a8abfde966bacd4260852155f7b523ef157f0b75a0e1e8a0784e463c3ef0bb69deb000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000ffffffff";
    let user_signature: vector<u8> = x"34bf3d641436c0ac35fb3d5460dac2b9cc3c4b6c6bb9ce3ffebd3c3c187f9b921b745d2b5e3b6882e2f7225c8ffd505f829be22116896aea4ecb9a76f894cd0b";
    let user_pubkey: vector<u8> = x"00661ca05b19191eabfd7b55421f8017fbcb251cc2a1e3aa07a1aaf9841d0bc3e3";
    
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_fee_action_bytes<TREASURY_TESTS>(&mut treasury, 78429106, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_package_id<TREASURY_TESTS>(&mut treasury, @0xbfde966bacd4260852155f7b523ef157f0b75a0e1e8a0784e463c3ef0bb69deb, ts.ctx());
    treasury::set_treasury_address<TREASURY_TESTS>(&mut treasury, TREASURY_ADMIN, ts.ctx());

    // Set mint fee
    let operator_cap = treasury::new_operator_cap();
    treasury.add_capability<TREASURY_TESTS, OperatorCap>(TREASURY_ADMIN, operator_cap, ts.ctx());
    treasury::set_mint_fee<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    
    // Assign ClaimerCap to AUTOCLAIMER
    let claimer_cap = treasury::new_claimer_cap();
    treasury.add_capability<TREASURY_TESTS, ClaimerCap>(AUTOCLAIMER, claimer_cap, ts.ctx());

    let mut clock = clock::create_for_testing(ts.ctx());
    clock.set_for_testing(1736941840000);
    
    // AUTOCLAIMER claims token for USER3
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        fee_payload,
        user_signature,
        user_pubkey,
        &clock,
        ts.ctx(),
    );

    // Try to claim again with the same payload
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        fee_payload,
        user_signature,
        user_pubkey,
        &clock,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);
    clock.destroy_for_testing();

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ERecipientPublicKeyMismatch)]
fun test_mint_with_fee_aborts_when_claim_permit_belongs_to_other_user() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    // Payload and fee permit belong to the different accoutns:
    // Payload belongs to USER2
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000405b1e71e6cea98724038d2a7a63152c8b423b61908647fd7f4c803380b4fc653c5530ccca1c165dd6877d290a3ca90e30ee9048344fcb63ad52cd4b9bcfa41698";
    // Claim permit belongs to USER3
    let fee_payload: vector<u8> = x"8175ca940000000000000000000000000000000000000000000000000000000005f5e0ff00000000000000000000000000000000000000000000000000000000ffffffff";
    let user_signature: vector<u8> = x"8517529e8af291e21ebcc5ed3eac67bc5f1225c9e5db0ac271ad57ad64c3999971b2013fe5076c58181e8ba636d6bcec632b807f7e2c0031c5004950ac68ff10";
    let user_pubkey: vector<u8> = x"0102299a0c81a93b517ace2b463aae907daeba2e83dae8039f836547817571198b5d";
    
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_fee_action_bytes<TREASURY_TESTS>(&mut treasury, 78429106, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Set mint fee
    let operator_cap = treasury::new_operator_cap();
    treasury.add_capability<TREASURY_TESTS, OperatorCap>(TREASURY_ADMIN, operator_cap, ts.ctx());
    treasury::set_mint_fee<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    
    // Assign ClaimerCap to AUTOCLAIMER
    let claimer_cap = treasury::new_claimer_cap();
    treasury.add_capability<TREASURY_TESTS, ClaimerCap>(AUTOCLAIMER, claimer_cap, ts.ctx());

    let mut clock = clock::create_for_testing(ts.ctx());
    clock.set_for_testing(1736941840000);
    
    // AUTOCLAIMER claims token for USER3
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        fee_payload,
        user_signature,
        user_pubkey,
        &clock,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);
    clock.destroy_for_testing();

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EFeeApprovalExpired)]
fun test_mint_with_fee_aborts_when_permit_has_expired(){
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a00101fde830a55138f976efefdb0c812071efa9cc3dc4657ab605ccab7af7e960000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040a8f2bfcac5f4a32ac79edcc801408c5b86dabc8a8e74e2116c11d96cfb73c5bb72339db14feb704222958304002f9e3582e4a533067f188d18988a05819e6696";

    let fee_payload: vector<u8> = x"04acbbb20100000000000000000000000000000000000000000000000000000035834a8abfde966bacd4260852155f7b523ef157f0b75a0e1e8a0784e463c3ef0bb69deb000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000ffffffff";
    let user_signature: vector<u8> = x"34bf3d641436c0ac35fb3d5460dac2b9cc3c4b6c6bb9ce3ffebd3c3c187f9b921b745d2b5e3b6882e2f7225c8ffd505f829be22116896aea4ecb9a76f894cd0b";
    let user_pubkey: vector<u8> = x"00661ca05b19191eabfd7b55421f8017fbcb251cc2a1e3aa07a1aaf9841d0bc3e3";
    
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_fee_action_bytes<TREASURY_TESTS>(&mut treasury, 78429106, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_package_id<TREASURY_TESTS>(&mut treasury, @0xbfde966bacd4260852155f7b523ef157f0b75a0e1e8a0784e463c3ef0bb69deb, ts.ctx());

    // Set mint fee
    let operator_cap = treasury::new_operator_cap();
    treasury.add_capability<TREASURY_TESTS, OperatorCap>(TREASURY_ADMIN, operator_cap, ts.ctx());
    treasury::set_mint_fee<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    
    // Assign ClaimerCap to AUTOCLAIMER
    let claimer_cap = treasury::new_claimer_cap();
    treasury.add_capability<TREASURY_TESTS, ClaimerCap>(AUTOCLAIMER, claimer_cap, ts.ctx());

    let mut clock = clock::create_for_testing(ts.ctx());
    clock.set_for_testing(4294967295001);
    
    // Mint and transfer tokens
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        fee_payload,
        user_signature,
        user_pubkey,
        &clock,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);
    clock.destroy_for_testing();

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ENoAuthRecord)]
fun test_mint_with_fee_aborts_when_called_without_claimer_cap() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8ad7a05696d40c52508ca34227c6041bb9affde7d84a2691325b4fc1b656bfd3f70000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000403589713bbc9a84b266df542430487464509f73a0607fee5ae3aa300ddba32bc548b88e5713c77d3361844733edea3ac79545c82bf05ef362d06402468976887f";

    let fee_payload: vector<u8> = x"8175ca940000000000000000000000000000000000000000000000000000000005f5e0ff00000000000000000000000000000000000000000000000000000000ffffffff";
    let user_signature: vector<u8> = x"8517529e8af291e21ebcc5ed3eac67bc5f1225c9e5db0ac271ad57ad64c3999971b2013fe5076c58181e8ba636d6bcec632b807f7e2c0031c5004950ac68ff10";
    let user_pubkey: vector<u8> = x"0102299a0c81a93b517ace2b463aae907daeba2e83dae8039f836547817571198b5d";
    
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_fee_action_bytes<TREASURY_TESTS>(&mut treasury, 2171980436, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Set mint fee
    let operator_cap = treasury::new_operator_cap();
    treasury.add_capability<TREASURY_TESTS, OperatorCap>(TREASURY_ADMIN, operator_cap, ts.ctx());
    treasury::set_mint_fee<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());

    let mut clock = clock::create_for_testing(ts.ctx());
    clock.set_for_testing(1736941840000);
    
    // Mint and transfer tokens
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        fee_payload,
        user_signature,
        user_pubkey,
        &clock,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);
    clock.destroy_for_testing();

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EMintNotAllowed)]
fun test_mint_with_fee_aborts_when_global_pause_enabled() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let mut denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8ad7a05696d40c52508ca34227c6041bb9affde7d84a2691325b4fc1b656bfd3f70000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000403589713bbc9a84b266df542430487464509f73a0607fee5ae3aa300ddba32bc548b88e5713c77d3361844733edea3ac79545c82bf05ef362d06402468976887f";

    let fee_payload: vector<u8> = x"8175ca940000000000000000000000000000000000000000000000000000000005f5e0ff00000000000000000000000000000000000000000000000000000000ffffffff";
    let user_signature: vector<u8> = x"8517529e8af291e21ebcc5ed3eac67bc5f1225c9e5db0ac271ad57ad64c3999971b2013fe5076c58181e8ba636d6bcec632b807f7e2c0031c5004950ac68ff10";
    let user_pubkey: vector<u8> = x"0102299a0c81a93b517ace2b463aae907daeba2e83dae8039f836547817571198b5d";
    
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_fee_action_bytes<TREASURY_TESTS>(&mut treasury, 2171980436, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Set mint fee
    let operator_cap = treasury::new_operator_cap();
    treasury.add_capability<TREASURY_TESTS, OperatorCap>(TREASURY_ADMIN, operator_cap, ts.ctx());
    treasury::set_mint_fee<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    
    // Assign ClaimerCap to AUTOCLAIMER
    let claimer_cap = treasury::new_claimer_cap();
    treasury.add_capability<TREASURY_TESTS, ClaimerCap>(AUTOCLAIMER, claimer_cap, ts.ctx());

    // Get the default multisig setup
    let (pks, weights, threshold) = multisig_tests::default_multisig_setup();
    let multisig_address = lbtc::multisig::derive_multisig_address(pks, weights, threshold);

    // Assign PauserCap to the multisig address
    ts.next_tx(TREASURY_ADMIN);
    let pauser_cap = treasury::new_pauser_cap();
    treasury.add_capability<TREASURY_TESTS, PauserCap>(multisig_address, pauser_cap, ts.ctx());

    // Enable global pause
    ts.next_tx(multisig_address);
    treasury::enable_global_pause(&mut treasury, &mut denylist,  pks, weights, threshold,ts.ctx());

    let mut clock = clock::create_for_testing(ts.ctx());
    clock.set_for_testing(1736941840000);
    
    // Mint and transfer tokens
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        fee_payload,
        user_signature,
        user_pubkey,
        &clock,
        ts.ctx(),
    );

    // User from the payload recieves the coins
    ts.next_tx(USER3);
    let coin: Coin<TREASURY_TESTS> = ts::take_from_sender(&mut ts);
    let balance = coin::value(&coin);
    debug::print(&balance);
    assert!(balance == 100000000 - 100);
    ts::return_to_sender(&mut ts, coin);

    //TODO: assert that mint fee was minted to the Treasury

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);
    clock.destroy_for_testing();

    ts.end();
}

fun init_and_mint_with_fee(payload: vector<u8>, proof: vector<u8>, fee_payload: vector<u8>, user_signature: vector<u8>, user_pubkey: vector<u8>) {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts, INIT_VALSET);
    let mut bascule: Bascule = init_bascule(&mut ts);
    
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_mint_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());
    treasury::set_fee_action_bytes<TREASURY_TESTS>(&mut treasury, 2171980436, ts.ctx());
    treasury::set_chain_id<TREASURY_TESTS>(&mut treasury, 452312848583266388373324160190187140051835877600158453279131187531808459402, ts.ctx());
    treasury::toggle_bascule_check<TREASURY_TESTS>(&mut treasury, ts.ctx());
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Set mint fee
    let operator_cap = treasury::new_operator_cap();
    treasury.add_capability<TREASURY_TESTS, OperatorCap>(TREASURY_ADMIN, operator_cap, ts.ctx());
    treasury::set_mint_fee<TREASURY_TESTS>(&mut treasury, 100, ts.ctx());
    
    // Assign ClaimerCap to AUTOCLAIMER
    let claimer_cap = treasury::new_claimer_cap();
    treasury.add_capability<TREASURY_TESTS, ClaimerCap>(AUTOCLAIMER, claimer_cap, ts.ctx());

    let mut clock = clock::create_for_testing(ts.ctx());
    clock.set_for_testing(1736941840000);
    
    // Mint and transfer tokens
    ts.next_tx(AUTOCLAIMER);
    treasury::mint_with_fee_v2<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        &mut bascule,
        payload,
        proof,
        fee_payload,
        user_signature,
        user_pubkey,
        &clock,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);
    ts::return_shared<Bascule>(bascule);
    clock.destroy_for_testing();

    ts.end();
}

#[test, expected_failure(abort_code = consortium::EInvalidPayload)]
fun test_mint_with_fee_aborts_when_recipient_different_address() {
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000403589713bbc9a84b266df542430487464509f73a0607fee5ae3aa300ddba32bc548b88e5713c77d3361844733edea3ac79545c82bf05ef362d06402468976887f";

    let fee_payload: vector<u8> = x"8175ca940000000000000000000000000000000000000000000000000000000005f5e0ff00000000000000000000000000000000000000000000000000000000ffffffff";
    let user_signature: vector<u8> = x"8517529e8af291e21ebcc5ed3eac67bc5f1225c9e5db0ac271ad57ad64c3999971b2013fe5076c58181e8ba636d6bcec632b807f7e2c0031c5004950ac68ff10";
    let user_pubkey: vector<u8> = x"0102299a0c81a93b517ace2b463aae907daeba2e83dae8039f836547817571198b5d";
    
    init_and_mint_with_fee(payload, proof, fee_payload, user_signature, user_pubkey);
}

#[test, expected_failure(abort_code = treasury::EInvalidUserSignature)]
fun test_mint_with_fee_aborts_when_permit_signature_is_invalid() {
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8ad7a05696d40c52508ca34227c6041bb9affde7d84a2691325b4fc1b656bfd3f70000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000403589713bbc9a84b266df542430487464509f73a0607fee5ae3aa300ddba32bc548b88e5713c77d3361844733edea3ac79545c82bf05ef362d06402468976887f";

    let fee_payload: vector<u8> = x"8175ca940000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000ffffffff";
    let user_signature: vector<u8> = x"8517529e8af291e21ebcc5ed3eac67bc5f1225c9e5db0ac271ad57ad64c3999971b2013fe5076c58181e8ba636d6bcec632b807f7e2c0031c5004950ac68ff10";
    let user_pubkey: vector<u8> = x"0102299a0c81a93b517ace2b463aae907daeba2e83dae8039f836547817571198b5d";
    
    init_and_mint_with_fee(payload, proof, fee_payload, user_signature, user_pubkey);
}

// === Getters and setters ===
#[test]
fun test_bascule_enable_and_disable_check() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Initialize bascule check
    ts.next_tx(TREASURY_ADMIN);
    treasury::toggle_bascule_check<TREASURY_TESTS>(
        &mut treasury,
        ts.ctx(),
    );
    assert!(treasury::is_bascule_check_enabled<TREASURY_TESTS>(&treasury) == true, EInvalidBasculeCheck);

    // Disable bascule check
    ts.next_tx(TREASURY_ADMIN);
    treasury::toggle_bascule_check<TREASURY_TESTS>(
        &mut treasury,
        ts.ctx(),
    );
    assert!(treasury::is_bascule_check_enabled<TREASURY_TESTS>(&treasury) == false, EInvalidBasculeCheck);
   
    test_utils::destroy(treasury);

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ENoBasculeCheck)]
fun test_bascule_check_is_disabled_by_default() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    // Get the bascule status
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury::is_bascule_check_enabled<TREASURY_TESTS>(&treasury) == true, EInvalidBasculeCheck);
   
    test_utils::destroy(treasury);

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ENoActionBytes)]
fun test_action_bytes_are_not_set_by_default() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    // Get the action bytes
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury::get_mint_action_bytes<TREASURY_TESTS>(&treasury) == 4075241340, EInvalidActionBytesCheck);
   
    test_utils::destroy(treasury);

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ENoUsedPayloads)]
fun test_used_payload_table_is_not_set_by_default() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    // Check if used payloads table exist
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury::is_payload_used<TREASURY_TESTS>(&treasury, b"1234"));
   
    test_utils::destroy(treasury);

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ERecordExists)]
fun test_set_used_payloads_aborts_when_table_exists() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);

    // Check if used payloads table exist
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());

    // Check if used payloads table exist
    ts.next_tx(TREASURY_ADMIN);
    treasury::set_payload_table<TREASURY_TESTS>(&mut treasury, ts.ctx());
   
    test_utils::destroy(treasury);

    ts.end();
}
