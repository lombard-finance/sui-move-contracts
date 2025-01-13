#[test_only]
module lbtc::treasury_tests;

use lbtc::treasury::{Self, ControlledTreasury, AdminCap, MinterCap, PauserCap, redeem, 
set_dust_fee_rate, set_burn_commission, set_treasury_address, toggle_withdrawal};
use std::string;
use sui::coin::{Self, Coin};
use sui::deny_list::{Self, DenyList};
use sui::test_scenario::{Self as ts, Scenario};
use sui::test_utils;
use lbtc::multisig_tests;

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
        TXID,
        IDX,
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
        TXID,
        IDX,
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
        TXID,
        IDX,
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
        TXID,
        IDX,
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

    // USER redeem coin
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

    // Now, attempt to redeem from USER
    redeem<TREASURY_TESTS>(&mut treasury, coin, script_pubkey, ts.ctx());
    
    ts.next_tx(TREASURY_ADMIN);

    let fee: Coin<TREASURY_TESTS> = ts.take_from_sender();

    assert!(fee.balance().value() == 100, ETreasuryAddressDoesNotHaveOnlyFee);

    ts.return_to_sender(fee);

    test_utils::destroy(treasury);
    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::EScriptPubkeyUnsupported)]
public fun test_redeem_unsupported_script_pubkey() {
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
public fun test_redeem_withdrawal_disabled() {
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
public fun test_redeem_insufficient_burn_commission() {
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
public fun test_redeem_no_burn_commission() {
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
public fun test_redeem_no_dust_fee_rate() {
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
public fun test_redeem_no_treasury_address() {
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
public fun test_redeem_amount_below_dust_limit() {
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

const EInvalidBasculeCheck: u64 = 1;
const EInvalidActionBytesCheck: u64 = 2;

const USER2: address = @0x0000000000000000000000000f90793a54e809bf708bd0fbcc63d311e3bb1be1;

fun init_consortium(ts: &mut Scenario): Consortium {
    let init_valset: vector<u8> = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000410420b871f3ced029e14472ec4ebc3c0448164942b123aa6af91a3386c1c403e0ebd3b4a5752a2b6c49e574619e6aa0549eb9ccd036b9bbc507e1f7f9712a236092000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
    ts.next_tx(TREASURY_ADMIN);
    consortium::init_for_testing(ts.ctx());
    ts.next_tx(TREASURY_ADMIN);
    let mut consortium: Consortium = ts.take_shared();
    consortium::set_initial_validator_set(&mut consortium, init_valset, ts.ctx());
    consortium
}

#[test]
fun test_manual_claim() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let mut treasury = create_test_currency(&mut ts);
    let denylist: DenyList = ts.take_shared();

    let mut consortium = init_consortium(&mut ts);
    
    let payload: vector<u8> = x"f2e73f7c000000000000000000000000000000000000000000000000000000000000000953ac220c4c7f0e8ac4266b54779f8a5e772705390a43f4ea2a59cd7c10305e4d0000000000000000000000000000000000000000000000000000000005f5e1008d3427b7fa9f07adb76208188930d49341246cef989a20b45a4619fd2ba6810a0000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000405ac3b079f374485585c941449e67e4fd33217c4a5579dc61f9d7b2704a00820c29d588f2981f7a2a429cf2df97ed1ead40f37d1c4fc45257ee37592861b4957000000000000000000000000000000000000000000000000000000000000000404588a44b8309f6602515e4aa5e6868b4b8131bea1a3d7e137049113b31c2ea384a3cea2e1ce7ecdd30cf6caabd22282dc65324de0c14e857c4850c981935a0260000000000000000000000000000000000000000000000000000000000000040b31e60fd4802a7d476dc9a75b280182c718ffd8a0ddf4630b4a91b4450a2c3ca5f9f34229c2c9da7a86881fefe7f41ffcafd96b6157da2729f59c4856e2d437a";

    ts.next_tx(TREASURY_ADMIN);
    treasury::set_action_bytes<TREASURY_TESTS>(&mut treasury, 4075241340, ts.ctx());

    // Mint and transfer tokens using the multisig address
    ts.next_tx(USER2);
    treasury::mint<TREASURY_TESTS>(
        &mut treasury,
        &mut consortium,
        &denylist,
        payload,
        proof,
        ts.ctx(),
    );

    test_utils::destroy(treasury);
    ts::return_shared(denylist);
    ts::return_shared<Consortium>(consortium);

    ts.end();
}

#[test]
fun test_bascule_check() {
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
fun test_no_bascule_check() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    // Get the bascule status
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury::is_bascule_check_enabled<TREASURY_TESTS>(&treasury) == true, EInvalidBasculeCheck);
   
    test_utils::destroy(treasury);

    ts.end();
}

#[test, expected_failure(abort_code = lbtc::treasury::ENoActionBytes)]
fun test_no_action_bytes() {
    let mut ts = ts::begin(TREASURY_ADMIN);
    let treasury = create_test_currency(&mut ts);

    // Get the action bytes
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury::get_action_bytes<TREASURY_TESTS>(&treasury) == 4075241340, EInvalidActionBytesCheck);
   
    test_utils::destroy(treasury);

    ts.end();
}