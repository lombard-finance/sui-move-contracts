#[test_only]
module consortium::consortium_tests;

use consortium::consortium::{Self, Consortium, init_for_testing};
use sui::test_scenario::{Self as ts};

const EInvalidEpoch: u64 = 0;

const INIT_VALSET: vector<u8> = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000410420b871f3ced029e14472ec4ebc3c0448164942b123aa6af91a3386c1c403e0ebd3b4a5752a2b6c49e574619e6aa0549eb9ccd036b9bbc507e1f7f9712a236092000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
const NEXT_VALSET: vector<u8> = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000004104bf6ee64a8d2fdc551ec8bb9ef862ef6b4bcb1805cdc520c3aa5866c0575fd3b514c5562c3caae7aec5cd6f144b57135c75b6f6cea059c3d08d1f39a9c227219d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000410437b84de6947b243626cc8b977bb1f1632610614842468dfa8f35dcbbc55a515e47f6fe259cffc671a719eaef444a0d689b16a90051985a13661840cf5e221503000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049a4ab212cb92775d227af4237c20b81f4221e9361d29007dfc16c79186b577cb6ba3f1b582ad0b5572c93f47e7506d66df7f2af05fa1828de0e511aac7b97828000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
const NEXT_PROOF: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000040760f6ac1f0ef347257731b26c1d66eba281c6437abe2ad9b49686fc8c5808c9f3604c3a2bd56e41f218d0ab5b42a9bf975ea80f50e4376dedc802bec978493850000000000000000000000000000000000000000000000000000000000000040b06cc31bc0013797e9db375b23bf4845060582bbf9fddfa11054f940fab5537932beaf8614ea478b59282a28b05ae447b3f72b53a5463a9b9a27f7471dae9c40000000000000000000000000000000000000000000000000000000000000004054225d664e28f047c30fca437c550a9bb033b2b79e0f91e9423f8eedcb6b810f31c0c7178517580d20a27062aa61cb4dd7fe06cbf37f981ed47a14ff4e84a770";

const SIGNATURES1: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000405ac3b079f374485585c941449e67e4fd33217c4a5579dc61f9d7b2704a00820c29d588f2981f7a2a429cf2df97ed1ead40f37d1c4fc45257ee37592861b4957000000000000000000000000000000000000000000000000000000000000000404588a44b8309f6602515e4aa5e6868b4b8131bea1a3d7e137049113b31c2ea384a3cea2e1ce7ecdd30cf6caabd22282dc65324de0c14e857c4850c981935a0260000000000000000000000000000000000000000000000000000000000000040b31e60fd4802a7d476dc9a75b280182c718ffd8a0ddf4630b4a91b4450a2c3ca5f9f34229c2c9da7a86881fefe7f41ffcafd96b6157da2729f59c4856e2d437a";
const PAYLOAD1: vector<u8> = x"f2e73f7c000000000000000000000000000000000000000000000000000000000000000953ac220c4c7f0e8ac4266b54779f8a5e772705390a43f4ea2a59cd7c10305e4d0000000000000000000000000000000000000000000000000000000005f5e1008d3427b7fa9f07adb76208188930d49341246cef989a20b45a4619fd2ba6810a0000000000000000000000000000000000000000000000000000000000000000";

const SIGNATURES2: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000004047791ea31e5fd811d966139cde444476c9788315921dcfa72b0940602b60b861396e737a270c46bc8ddc79b8f9810f51a830ac151c167e85b8e43878fb9c70a900000000000000000000000000000000000000000000000000000000000000406cdedcff3afc19e38477154a8b256d790652e32f48bca7bfe5f129a1c7314d1c30f5348af4842cdd82c0be6b36bc3b301b177a961f251bba0ab92647feb0bf3c00000000000000000000000000000000000000000000000000000000000000400f38fc56a305e35aaff837bde375d31a969b57e8f8abe68dbed1a20ad68f99ea0b3fee8af26bfc068344a37dbbc3eb8184f3baa9479ad94a1378a1f9cbd75ac3";
const PAYLOAD2: vector<u8> = x"f2e73f7c000000000000000000000000000000000000000000000000000000000000000953ac220c4c7f0e8ac4266b54779f8a5e772705390a43f4ea2a59cd7c10305e4d0000000000000000000000000000000000000000000000000000000005f5e1007be82fe6b41e7a312d9dc8b9ad73bcec5e4235372289cbd78667d40d51bd600e0000000000000000000000000000000000000000000000000000000000000000";

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
        consortium::set_initial_validator_set(&mut consortium, INIT_VALSET, scenario.ctx());
        assert!(consortium.get_epoch() == 1, EInvalidEpoch);
        ts::return_shared<Consortium>(consortium);
    };

    // Validate the payload
    scenario.next_tx(USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::validate_payload(&mut consortium, PAYLOAD1, SIGNATURES1);
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
        consortium::set_initial_validator_set(&mut consortium, INIT_VALSET, scenario.ctx());
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

#[test]
fun test_next_validator_set_and_validation() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    // The admin sets the initial validator set
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_initial_validator_set(&mut consortium, INIT_VALSET, scenario.ctx());
        assert!(consortium.get_epoch() == 1, EInvalidEpoch);
        ts::return_shared<Consortium>(consortium);
    };

    // Transaction to configure the next validator set
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_next_validator_set(&mut consortium, NEXT_VALSET, NEXT_PROOF);
        assert!(consortium.get_epoch() == 2, EInvalidEpoch);
        ts::return_shared<Consortium>(consortium);
    };

    // Validate the payload signed from the next validator set
    scenario.next_tx(USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::validate_payload(&mut consortium, PAYLOAD2, SIGNATURES2);
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
        consortium::set_initial_validator_set(&mut consortium, INIT_VALSET, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };
    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EInvalidPayload)]
fun test_invalid_payload() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_initial_validator_set(&mut consortium, INIT_VALSET, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::validate_payload(&mut consortium, PAYLOAD2, SIGNATURES1);
        ts::return_shared<Consortium>(consortium);
    };

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EValidatorSetDoesNotExist)]
fun test_nonexistent_validator_set() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    scenario.next_tx(ADMIN_USER);
    {
        let consortium = ts::take_shared<Consortium>(scenario);
        consortium::get_validator_set(&consortium, 0);
        ts::return_shared<Consortium>(consortium);
    };

    ts::end(scenario_val);
}

// === Tests with wrong payloads ===

#[test, expected_failure(abort_code = consortium::EWeightsLowerThanThreshold)]
fun test_weights_lower_than_threshold() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    let payload = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
    
    // Set the initial validator set
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_initial_validator_set(&mut consortium, payload, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EInvalidThreshold)]
fun test_invalid_threshold() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    let payload = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";

    // Set the initial validator set
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_initial_validator_set(&mut consortium, payload, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EZeroWeight)]
fun test_zero_weight() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    let payload = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000";
    
    // Set the initial validator set
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_initial_validator_set(&mut consortium, payload, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EInvalidAction)]
fun test_invalid_action() {
    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    let payload = x"4abb1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
    
    // Set the initial validator set
    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_initial_validator_set(&mut consortium, payload, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    ts::end(scenario_val);
}

#[test, expected_failure(abort_code = consortium::EInvalidPayload)]
fun test_invalid_signature() {
    let init_valset: vector<u8> = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
    let payload: vector<u8> = x"f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    let proof: vector<u8> = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000405b1e71e6cea98724038d2a7a63152c8b423b61908647fd7f4c803380b4fc653c5530ccca1c165dd6877d290a3ca90e30ee9048344fcb63ad52cd4b9bcfa416980000000000000000000000000000000000000000000000000000000000000000";

    // Begin a new test scenario with ADMIN_USER
    let mut scenario_val = ts::begin(ADMIN_USER);
    let scenario = &mut scenario_val;

    {
        init_for_testing(scenario.ctx());
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::set_initial_validator_set(&mut consortium, init_valset, scenario.ctx());
        ts::return_shared<Consortium>(consortium);
    };

    scenario.next_tx(ADMIN_USER);
    {
        let mut consortium = ts::take_shared<Consortium>(scenario);
        consortium::validate_payload(&mut consortium, payload, proof);
        ts::return_shared<Consortium>(consortium);
    };

    ts::end(scenario_val);
}