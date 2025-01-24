#[test_only]
module bascule::bascule_tests;

use bascule::bascule;
use std::type_name;
use sui::test_scenario as ts;

const OWNER_ADDR: address = @0x31337;
const PAUSER_ADDR: address = @0xd34ad;
const REPORTER_ADDR: address = @0xb33f;
const LBTC_ADDR: address = @0x1B7C;

/// Test Witness struct for LBTC
public struct TestWitness has drop {}

/// Test Witness struct for Owner
public struct TestWitnessOwner has drop {}

/// One more witness for testing as non validator
public struct TestInvalidWitness has drop {}

/// Helper struct to hold deposit details
public struct DepositDetails has copy, drop {
    to: address,
    amount: u64,
    tx_id: vector<u8>,
    index: u32,
}

/// Get the deposit id for a deposit
public fun to_deposit_id(deposit: &DepositDetails): u256 {
    bascule::test_to_deposit_id(deposit.to, deposit.amount, deposit.tx_id, deposit.index)
}

const DEPOSIT_ID_10: u256 = 10;

/// Deploy Bascule module and grant permissions
fun setup_bascule(scenario: &mut ts::Scenario) {
    // Deploy the Bascule module
    bascule::test_init(ts::ctx(scenario));
    // Grant owner, pauser, and withdrawal validator permissions
    ts::next_tx(scenario, OWNER_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);
    let owner_cap = ts::take_from_sender<bascule::BasculeOwnerCap>(scenario);
    bascule::grant_reporter(&owner_cap, REPORTER_ADDR, ts::ctx(scenario));
    bascule::grant_pauser(&owner_cap, PAUSER_ADDR, ts::ctx(scenario));
    let witness_type = type_name::get<TestWitness>();
    bascule::add_withdrawal_validator(
        &owner_cap,
        &mut bascule,
        witness_type.into_string(),
        ts::ctx(scenario),
    );
    assert!(bascule.is_validator(witness_type.into_string()));
    ts::return_to_address<bascule::BasculeOwnerCap>(OWNER_ADDR, owner_cap);
    ts::return_shared<bascule::Bascule>(bascule);
    // advance to the next epoch
    ts::next_epoch(scenario, OWNER_ADDR);
}

fun pause_bascule(scenario: &mut ts::Scenario) {
    ts::next_tx(scenario, PAUSER_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);
    let pauser_cap = ts::take_from_sender<bascule::BasculePauserCap>(scenario);
    assert!(!bascule.is_paused());
    bascule::pause(&pauser_cap, &mut bascule, ts::ctx(scenario));
    assert!(bascule.is_paused());
    ts::return_to_address<bascule::BasculePauserCap>(PAUSER_ADDR, pauser_cap);
    ts::return_shared<bascule::Bascule>(bascule);
}

fun unpause_bascule(scenario: &mut ts::Scenario) {
    ts::next_tx(scenario, PAUSER_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);
    let pauser_cap = ts::take_from_sender<bascule::BasculePauserCap>(scenario);
    assert!(bascule.is_paused());
    bascule::unpause(&pauser_cap, &mut bascule, ts::ctx(scenario));
    assert!(!bascule.is_paused());
    ts::return_to_address<bascule::BasculePauserCap>(PAUSER_ADDR, pauser_cap);
    ts::return_shared<bascule::Bascule>(bascule);
}

fun set_threshold(scenario: &mut ts::Scenario, threshold: u64) {
    ts::next_tx(scenario, OWNER_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);
    let owner_cap = ts::take_from_sender<bascule::BasculeOwnerCap>(scenario);
    bascule::update_validate_threshold(&owner_cap, &mut bascule, threshold, ts::ctx(scenario));
    assert!(bascule.get_validate_threshold() == threshold);
    ts::return_to_address<bascule::BasculeOwnerCap>(OWNER_ADDR, owner_cap);
    ts::return_shared<bascule::Bascule>(bascule);
}

fun report_deposit(scenario: &mut ts::Scenario, deposit_id: u256) {
    // Reporter reports deposit
    ts::next_tx(scenario, REPORTER_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);
    let reporter_cap = ts::take_from_sender<bascule::BasculeReporterCap>(scenario);
    bascule::report_deposit(&reporter_cap, &mut bascule, deposit_id, ts::ctx(scenario));
    assert!(!bascule.deposit_is_unreported(deposit_id));
    assert!(bascule.deposit_is_reported(deposit_id));
    assert!(!bascule.deposit_is_withdrawn(deposit_id));
    ts::return_to_address<bascule::BasculeReporterCap>(REPORTER_ADDR, reporter_cap);
    ts::return_shared<bascule::Bascule>(bascule);
}

/// Withdraw a deposit.
/// Uses the TestWitnessOwner for the owner and TestWitness for everything else
fun withdraw_deposit(scenario: &mut ts::Scenario, sender: address, deposit: &DepositDetails) {
    ts::next_tx(scenario, sender);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);

    let deposit_id = deposit.to_deposit_id();
    if (sender.to_u256() == OWNER_ADDR.to_u256()) {
        // validate withdrawal as owner
        bascule::validate_withdrawal(
            TestWitnessOwner {},
            &mut bascule,
            deposit.to,
            deposit.amount,
            deposit.tx_id,
            deposit.index,
        );
    } else {
        // validate withdrawal as validator (i.e., LBTC)
        bascule::validate_withdrawal(
            TestWitness {},
            &mut bascule,
            deposit.to,
            deposit.amount,
            deposit.tx_id,
            deposit.index,
        );
    };

    assert!(!bascule.deposit_is_unreported(deposit_id));
    assert!(!bascule.deposit_is_reported(deposit_id));
    assert!(bascule.deposit_is_withdrawn(deposit_id));
    ts::return_shared<bascule::Bascule>(bascule);
}

/**************************************************
** Sanity checking tests **************************
**************************************************/

#[test]
fun zero_serde() {
    // for non-evm chains we use the 0x00.. prefix to ensure uniqueness
    // this tests just makes sure that the encoding of u256 0 is all zeros
    // 32-byte vector
    use sui::bcs;
    let mut hash_data = vector<u8>[];
    hash_data.append(bcs::to_bytes(&0u256));
    assert!(hash_data.length() == 32);
    assert!(hash_data.all!(|el| el == 0));
}

/**************************************************
** Reporter tests *********************************
**************************************************/

#[test, expected_failure(abort_code = ::bascule::bascule::EPaused)]
fun test_pause_report() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    // Pause the contract
    pause_bascule(scenario);

    // Reporter reports deposit fails
    report_deposit(scenario, DEPOSIT_ID_10);

    ts::end(scenario_val);
}

fun mk_deposits(): vector<DepositDetails> {
    let deposit_0: DepositDetails = DepositDetails {
        to: @0x3f6bf1c36ccbb59eaf8415301a0cec73c344a079,
        amount: 18000000000,
        tx_id: b"2ff9eba546648403fbe6de1b5e287e5d484bf581ce3974ec816c28352d3b939b",
        index: 0,
    };

    let deposit_1: DepositDetails = DepositDetails {
        to: @0x3f6bf1c36ccbb59eaf8415301a0cec73c344a079,
        amount: 28000000000,
        tx_id: b"3eeeeeeeeeeefb40308bbbbbbbbbbbbbbbbbbbbbbbbbbbbbaaaaaaaaaaaaaaaa",
        index: 1,
    };
    vector[deposit_0, deposit_1]
}

#[test]
fun test_report_and_withdraw_after_unpause() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposits = mk_deposits();
    let deposit_0 = deposits.borrow(0);
    let deposit_1 = deposits.borrow(1);

    report_deposit(scenario, deposit_0.to_deposit_id());
    pause_bascule(scenario);
    unpause_bascule(scenario);
    report_deposit(scenario, deposit_1.to_deposit_id());
    withdraw_deposit(scenario, LBTC_ADDR, deposit_0);
    withdraw_deposit(scenario, LBTC_ADDR, deposit_1);

    ts::end(scenario_val);
}

#[test]
fun test_report_idempotent() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    report_deposit(scenario, DEPOSIT_ID_10);
    report_deposit(scenario, DEPOSIT_ID_10);

    ts::end(scenario_val);
}

#[test]
fun test_report_after_withdrawal() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposit = mk_deposits().borrow(0);
    let deposit_id = deposit.to_deposit_id();

    report_deposit(scenario, deposit_id);
    withdraw_deposit(scenario, LBTC_ADDR, deposit);

    // report deposit again (has no effect on status)
    ts::next_tx(scenario, REPORTER_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);
    let reporter_cap = ts::take_from_sender<bascule::BasculeReporterCap>(scenario);
    bascule::report_deposit(&reporter_cap, &mut bascule, deposit_id, ts::ctx(scenario));
    ts::return_to_address<bascule::BasculeReporterCap>(REPORTER_ADDR, reporter_cap);
    // make sure deposit is still marked as withdrawn
    assert!(!bascule.deposit_is_unreported(deposit_id));
    assert!(!bascule.deposit_is_reported(deposit_id));
    assert!(bascule.deposit_is_withdrawn(deposit_id));
    ts::return_shared<bascule::Bascule>(bascule);

    ts::end(scenario_val);
}

/**************************************************
** Threshold tests *******************************
**************************************************/

#[test, expected_failure(abort_code = ::bascule::bascule::EPaused)]
fun test_pause_update_threshold() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    // Pause the contract
    pause_bascule(scenario);

    // Update the threshold
    set_threshold(scenario, 3);

    ts::end(scenario_val);
}

#[test]
fun test_update_threshold() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    // Check the initial threshold
    let bascule = ts::take_shared<bascule::Bascule>(scenario);
    assert!(bascule.get_validate_threshold() == 0);
    ts::return_shared<bascule::Bascule>(bascule);

    // Update the threshold
    set_threshold(scenario, 3);
    ts::next_tx(scenario, OWNER_ADDR);

    // Check the updated threshold
    let bascule = ts::take_shared<bascule::Bascule>(scenario);
    assert!(bascule.get_validate_threshold() == 3);
    ts::return_shared<bascule::Bascule>(bascule);

    ts::end(scenario_val);
}

/**************************************************
** Withdrawal tests *******************************
**************************************************/

#[test, expected_failure(abort_code = ::bascule::bascule::ENotValidator)]
fun test_withdraw_as_non_validator() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposit = mk_deposits().borrow(0);
    // Ok, since owner is also initialized to reporter
    report_deposit(scenario, deposit.to_deposit_id());

    ts::next_tx(scenario, LBTC_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);

    bascule::validate_withdrawal(
        TestInvalidWitness {},
        &mut bascule,
        deposit.to,
        deposit.amount,
        deposit.tx_id,
        deposit.index,
    );
    ts::return_shared<bascule::Bascule>(bascule);

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = ::bascule::bascule::ENotValidator)]
fun test_withdraw_remove_validator() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposits = mk_deposits();
    let deposit_0 = deposits.borrow(0);
    let deposit_1 = deposits.borrow(1);

    report_deposit(scenario, deposit_0.to_deposit_id());
    report_deposit(scenario, deposit_1.to_deposit_id());
    withdraw_deposit(scenario, LBTC_ADDR, deposit_0);

    // remove validator
    ts::next_tx(scenario, OWNER_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);
    let owner_cap = ts::take_from_sender<bascule::BasculeOwnerCap>(scenario);
    let witness_type = type_name::get<TestWitness>();
    bascule::remove_withdrawal_validator(
        &owner_cap,
        &mut bascule,
        witness_type.into_string(),
        ts::ctx(scenario),
    );
    assert!(!bascule.is_validator(witness_type.into_string()));
    ts::return_to_address<bascule::BasculeOwnerCap>(OWNER_ADDR, owner_cap);
    ts::return_shared<bascule::Bascule>(bascule);

    withdraw_deposit(scenario, LBTC_ADDR, deposit_1);

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = ::bascule::bascule::EPaused)]
fun test_pause_withdraw() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposit = mk_deposits().borrow(0);
    report_deposit(scenario, deposit.to_deposit_id());
    pause_bascule(scenario);
    withdraw_deposit(scenario, LBTC_ADDR, deposit);

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = ::bascule::bascule::EAlreadyWithdrawn)]
fun test_withdraw_twice() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposit = mk_deposits().borrow(0);

    report_deposit(scenario, deposit.to_deposit_id());
    withdraw_deposit(scenario, LBTC_ADDR, deposit);
    withdraw_deposit(scenario, LBTC_ADDR, deposit);

    ts::end(scenario_val);
}

#[test]
fun test_report_and_withdraw() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    // Reporter reports deposit
    let deposit = mk_deposits().borrow(0);
    let deposit_id = deposit.to_deposit_id();

    // check deposit status before report
    let bascule = ts::take_shared<bascule::Bascule>(scenario);
    assert!(bascule.deposit_is_unreported(deposit_id));
    assert!(!bascule.deposit_is_reported(deposit_id));
    assert!(!bascule.deposit_is_withdrawn(deposit_id));
    ts::return_shared<bascule::Bascule>(bascule);

    report_deposit(scenario, deposit_id);
    withdraw_deposit(scenario, LBTC_ADDR, deposit);

    ts::end(scenario_val);
}

#[test]
fun test_report_and_withdraw_as_lbtc_and_owner() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    // Report deposits
    let deposits = mk_deposits();
    let deposit_0 = deposits.borrow(0);
    let deposit_1 = deposits.borrow(1);

    report_deposit(scenario, deposit_0.to_deposit_id());
    report_deposit(scenario, deposit_1.to_deposit_id());

    // Add owner as validator validator
    ts::next_tx(scenario, OWNER_ADDR);
    let mut bascule = ts::take_shared<bascule::Bascule>(scenario);
    let owner_cap = ts::take_from_sender<bascule::BasculeOwnerCap>(scenario);
    let witness_type = type_name::get<TestWitnessOwner>();
    bascule::add_withdrawal_validator(
        &owner_cap,
        &mut bascule,
        witness_type.into_string(),
        ts::ctx(scenario),
    );
    assert!(bascule.is_validator(witness_type.into_string()));
    ts::return_to_address<bascule::BasculeOwnerCap>(OWNER_ADDR, owner_cap);
    ts::return_shared<bascule::Bascule>(bascule);

    // Withdraw deposits as LBTC
    withdraw_deposit(scenario, LBTC_ADDR, deposit_0);
    // Withdraw deposit as owner
    withdraw_deposit(scenario, OWNER_ADDR, deposit_1);

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = ::bascule::bascule::EWithdrawalFailedValidation)]
fun test_withdraw_no_report_zero_threshold() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposit = mk_deposits().borrow(0);

    // check deposit status
    let bascule = ts::take_shared<bascule::Bascule>(scenario);
    assert!(bascule.deposit_is_unreported(deposit.to_deposit_id()));
    ts::return_shared<bascule::Bascule>(bascule);

    // fail to withdraw deposit
    withdraw_deposit(scenario, LBTC_ADDR, deposit);

    ts::end(scenario_val);
}

#[test]
fun test_withdraw_no_report_below_nonzero_threshold() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let threshold = 3;
    let deposit_0 = mk_deposits().borrow_mut(0);
    deposit_0.amount = threshold + 1;

    // report deposit 0
    report_deposit(scenario, deposit_0.to_deposit_id());
    // raise threshold
    set_threshold(scenario, threshold);

    // ok withdraw reported deposit > threshold
    withdraw_deposit(scenario, LBTC_ADDR, deposit_0);

    // ok withdraw unreported deposit < threshold
    let deposit_1 = mk_deposits().borrow_mut(1);
    deposit_1.amount = threshold - 1;
    withdraw_deposit(scenario, LBTC_ADDR, deposit_1);

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = ::bascule::bascule::EWithdrawalFailedValidation)]
fun test_withdraw_no_report_above_nonzero_threshold() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposits = mk_deposits();
    let deposit_0 = deposits.borrow(0);
    let deposit_1 = deposits.borrow(1);
    let min = if (deposit_0.amount < deposit_1.amount) {
        deposit_1.amount
    } else {
        deposit_0.amount
    };
    assert!(min > 1); // use use min - 1 as threshold

    // report deposit
    report_deposit(scenario, deposit_0.to_deposit_id());
    // raise threshold
    set_threshold(scenario, min - 1);

    withdraw_deposit(scenario, LBTC_ADDR, deposit_0);

    // fail withdraw unreported deposit >= threshold
    withdraw_deposit(scenario, LBTC_ADDR, deposit_1);

    ts::end(scenario_val);
}

#[test]
fun test_withdraw_report_below_nonzero_threshold() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposit = mk_deposits().borrow(0);
    // raise threshold above deposit amount
    set_threshold(scenario, deposit.amount + 1);

    // withdraw deposit below threshold ok
    withdraw_deposit(scenario, LBTC_ADDR, deposit);

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = ::bascule::bascule::EAlreadyWithdrawn)]
fun test_withdraw_2x_report_below_nonzero_threshold() {
    let mut scenario_val = ts::begin(OWNER_ADDR);
    let scenario = &mut scenario_val;
    setup_bascule(scenario);

    let deposit = mk_deposits().borrow(0);
    // raise threshold above deposit amount
    set_threshold(scenario, deposit.amount + 1);

    // withdraw deposit below threshold ok
    withdraw_deposit(scenario, LBTC_ADDR, deposit);
    // withdraw same deposit again fails
    withdraw_deposit(scenario, LBTC_ADDR, deposit);

    ts::end(scenario_val);
}