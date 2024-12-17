#[test_only]
module consortium::consortium_tests;

use consortium::consortium::{Self, Consortium, init_for_testing};
use sui::test_scenario::{Self as ts};

const EInvalidEpoch: u64 = 0;
const EInvalidPayload: u64 = 1;

const SIGNATURES: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000040486dbc2308c3722c280a96a421e48d8c984bca9f48868e280ce1c8b1b08238cd671de8b18dd200053aef1727a80e83171805da0013c1b6d1ff28c5abfd73d7950000000000000000000000000000000000000000000000000000000000000040ae04a516c2a64625d865cf5cc9134aad909f20bed93ddf7ea8a440b6ea4bf9ae5b40bce9a00cfd157985ac61bbb56833e61b8e81018c5e1b52172f110e23e3fa0000000000000000000000000000000000000000000000000000000000000040e474e99a95f80a6f84fd659bcf5d158e027f06eed692f90a92c5b0154aec14c91a9555d2b3162125118e8b264c2b43e041f8cc9091ce45cc35d2fd8acf3fc295";
const PAYLOAD: vector<u8> = x"f2e73f7c0000000000000000000000000000000000000000000000000000000000aa36a70000000000000000000000000f90793a54e809bf708bd0fbcc63d311e3bb1be100000000000000000000000000000000000000000000000000000000000059d85a7c1a028fe68c29a449a6d8c329b9bdd39d8b925ba0f8abbde9fe398430fac40000000000000000000000000000000000000000000000000000000000000000";
const SIGNERS: vector<vector<u8>> = vector[x"027378e006183e9a5de1537b788aa9d107c67189cd358efc1d53a5642dc0a37311", x"03ac2fec1927f210f2056d13c9ba0706666f333ed821d2032672d71acf47677eae", x"02b56056d0cb993765f963aeb530f7687c44d875bd34e38edc719bb117227901c5"];
const HASH: vector<u8> = x"f5638b4d4846c87bc4d9647a13af858401ac6b30469c61dd894eb05344ef8c6b";

const ADMIN_USER: address = @0x1;
const USER: address = @0x2;

#[test]
fun test_consortium_validation() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    // Set the initial validator set
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_next_validator_set(&mut consortium, SIGNERS, scenario.ctx());
        assert!(consortium.get_epoch() == 0, EInvalidEpoch);
        ts::return_shared<Consortium>(consortium);
    };

    // Validate the payload
    scenario.next_tx(USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        assert!(!consortium.is_payload_used(HASH), EInvalidPayload);
        consortium::validate_payload(&mut consortium, PAYLOAD, SIGNATURES);
        assert!(consortium.is_payload_used(HASH), EInvalidPayload);
        ts::return_shared<Consortium>(consortium); 
    };
    ts::end(scenario_val);
}

#[test]
fun test_new_admin_and_validator_set() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    // Set the initial validator set
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_next_validator_set(&mut consortium, SIGNERS, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    // Add a new admin
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::add_admin(&mut consortium, USER, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    // The new admin sets the next validator set
    scenario.next_tx(USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_next_validator_set(&mut consortium, SIGNERS, scenario.ctx());
        assert!(consortium.get_epoch() == 1, EInvalidEpoch);
        ts::return_shared<Consortium>(consortium);
    };

    // The new admin removes the old admin
    scenario.next_tx(USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::remove_admin(&mut consortium, ADMIN_USER, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };
    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EAdminAlreadyExists)]
fun test_add_existing_admin() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::add_admin(&mut consortium, ADMIN_USER, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };
    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EAdminDoesNotExist)]
fun test_remove_nonexistent_admin() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::add_admin(&mut consortium, USER, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::remove_admin(&mut consortium, @0x3, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };
    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::ECannotRemoveLastAdmin)]
fun test_remove_last_admin() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::remove_admin(&mut consortium, ADMIN_USER, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };
    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EUnauthorized)]
fun test_set_validators_unauthorized() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    scenario.next_tx(USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_next_validator_set(&mut consortium, SIGNERS, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };
    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EUsedPayload)]
fun test_used_payload() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_next_validator_set(&mut consortium, SIGNERS, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::validate_payload(&mut consortium, PAYLOAD, SIGNATURES);
        ts::return_shared<Consortium>(consortium);
    };

    scenario.next_tx(USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::validate_payload(&mut consortium, PAYLOAD, SIGNATURES);
        ts::return_shared<Consortium>(consortium);
    };
    ts::end(scenario_val);
}