#[test_only]
module lbtc::lbtc_tests {

    use lbtc::lbtc::{LBTC, init_for_testing};
    use lbtc::treasury::{ControlledTreasury, AdminCap};
    use sui::test_scenario::{Self as ts};

    const ADMIN_USER: address = @0x1;

    /// No authorization record exists for the action.
    const ENoAuthRecord: u64 = 0;

     #[test]
    fun test_init_success() {
        // Begin a new test scenario with ADMIN_USER
        let mut scenario_val = ts::begin(ADMIN_USER);
        let scenario = &mut scenario_val;

        {
            init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, ADMIN_USER);
        {
            let controlled_treasury = ts::take_shared<ControlledTreasury<LBTC>>(scenario);
            assert!(controlled_treasury.has_cap<LBTC, AdminCap>(ADMIN_USER), ENoAuthRecord);
            ts::return_shared<ControlledTreasury<LBTC>>(controlled_treasury);

        };
        ts::end(scenario_val);
    }
}
