module lbtc::treasury_tests;

use lbtc::treasury::{Self, AdminCap, MinterCap, PauserCap};
use std::string;
use sui::coin::{Self, DenyCapV2, TreasuryCap};
use sui::test_scenario as ts;
use sui::test_utils;

const TREASURY_ADMIN: address = @0x3;
const MINTER: address = @0x4;

public struct TREASURY_TESTS has drop {}

#[test]
fun test_multiple_roles_for_single_address() {
    // Start a test transaction scenario
    let mut ts = ts::begin(TREASURY_ADMIN);

    // Initialize the ControlledTreasury with a dummy TreasuryCap and DenyCap
    let (treasury_cap, deny_cap) = create_test_currency(ts.ctx());
    let mut treasury = treasury::new<TREASURY_TESTS>(
        treasury_cap,
        deny_cap,
        TREASURY_ADMIN,
        ts.ctx(),
    );

    // Ensure the initial admin has an AdminCap
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury.has_cap<TREASURY_TESTS, AdminCap>(TREASURY_ADMIN));

    // Assign MinterCap to the same address
    treasury.assign_minter(TREASURY_ADMIN, 1000, ts.ctx());

    // Verify that the address has MinterCap
    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury.has_cap<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN));

    // Assign PauserCap to the same address
    treasury.assign_pauser(TREASURY_ADMIN, ts.ctx());

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

#[test, expected_failure(abort_code = ::lbtc::treasury::ERecordExists)]
fun test_duplicate_role_assignment() {
    let mut ts = ts::begin(TREASURY_ADMIN);

    let (treasury_cap, deny_cap) = create_test_currency(ts.ctx());
    let mut treasury = treasury::new<TREASURY_TESTS>(
        treasury_cap,
        deny_cap,
        TREASURY_ADMIN,
        ts.ctx(),
    );

    ts.next_tx(TREASURY_ADMIN);
    treasury.assign_minter(MINTER, 1000, ts.ctx());

    // Attempt to assign MinterCap again to the same address
    treasury.assign_minter(MINTER, 1000, ts.ctx());

    test_utils::destroy(treasury);
    ts.end();
}

#[test]
fun test_role_removal() {
    let mut ts = ts::begin(TREASURY_ADMIN);

    let (treasury_cap, deny_cap) = create_test_currency(ts.ctx());
    let mut treasury = treasury::new<TREASURY_TESTS>(
        treasury_cap,
        deny_cap,
        TREASURY_ADMIN,
        ts.ctx(),
    );

    ts.next_tx(TREASURY_ADMIN);
    treasury.assign_minter(MINTER, 1000, ts.ctx());

    ts.next_tx(TREASURY_ADMIN);
    assert!(treasury.has_cap<TREASURY_TESTS, MinterCap>(MINTER));

    // Remove the MinterCap
    treasury.remove_capability<TREASURY_TESTS, MinterCap>(MINTER, ts.ctx());

    ts.next_tx(TREASURY_ADMIN);
    assert!(!treasury.has_cap<TREASURY_TESTS, MinterCap>(TREASURY_ADMIN));

    test_utils::destroy(treasury);
    ts.end();
}

#[test_only]
public(package) fun create_test_currency(
    ctx: &mut TxContext,
): (TreasuryCap<TREASURY_TESTS>, DenyCapV2<TREASURY_TESTS>) {
    let (treasury, deny_cap, metadata) = coin::create_regulated_currency_v2(
        TREASURY_TESTS {},
        6,
        b"TESTCOIN",
        b"",
        b"",
        option::none(),
        false,
        ctx,
    );

    transfer::public_freeze_object(metadata);
    (treasury, deny_cap)
}
