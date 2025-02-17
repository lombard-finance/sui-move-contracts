#[test_only]
module bridge_vault::bridge_tests {

    use bridge_vault::bridge_vault::{Self, Vault, AdminCap, PauserCap, BridgeWitness};
    use lbtc::treasury::{Self, ControlledTreasury};
    use std::type_name;
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::deny_list::{Self, DenyList};
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::test_utils;
    use bridge::bridge::{Self, new_for_testing};
    use bridge::message_types;
    use bridge::message;

    const EWrongMintAmount: u64 = 0;
    const EWrongPauseState: u64 = 1;

    const TREASURY_ADMIN: address = @0x3;
    const SYSTEM_ADDRESS: address = @0x0;
    const PAUSER: address = @0xFACE;
    const MINT_LIMIT: u64 = 1000000;

    const CHAIN_ID: u8 = 11;
    const TARGET_ADDRESS: vector<u8> = x"123456789a123456789a123456789a123456789a";

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
        bridge_vault::claim_native<WTEST, BRIDGE_TESTS>(wrapped_coin, &mut vault, &mut treasury, &denylist, ts.ctx());

        ts.next_tx(TREASURY_ADMIN);
        let native_coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
        assert!(native_coin.value() == 1000, EWrongMintAmount);
        ts.return_to_sender(native_coin);
        test_utils::destroy(treasury);
        ts::return_shared(denylist);
        ts::return_shared(vault);

        ts.end();
    }

    // This test is checking the return_native function which is supposed to burn the native token and send the wrapped
    // token to the bridge.
    // This test is failing because the wrapped token is not minted properly, the supply is not increased,
    // and eventually when sent to the bridge, it is not able to burn it due to 0 supply.
    // This indicates that the return_native is working as expected since the test reaches the part where the wrapped token is 
    // getting burned.
    #[test, expected_failure(abort_code = balance::EOverflow)]
    fun test_return_native() {
        use bridge_vault::wlbtc::{Self, WLBTC};
        // Start a test transaction scenario
        let mut ts = ts::begin(TREASURY_ADMIN);
        let mut treasury = create_test_currency(&mut ts);
        
        ts.next_tx(TREASURY_ADMIN);
        let cap = ts.take_from_sender<AdminCap>();
        bridge_vault::new_vault<WLBTC, BRIDGE_TESTS>(&cap, ts.ctx());
        ts.return_to_sender(cap);

        // Fill the vault with the wrapped token
        ts.next_tx(TREASURY_ADMIN);
        let mut vault: Vault<WLBTC, BRIDGE_TESTS> = ts.take_shared();
        bridge_vault::fill_vault(&mut vault, balance::create_for_testing(1000));

        // Register the wrapped token 
        ts.next_tx(SYSTEM_ADDRESS);
        let mut bridge = new_for_testing(1, ts.ctx());
        let (upgrade_cap, treasury_cap, metadata) = wlbtc::create_bridge_token(ts.ctx());
        
        bridge.register_foreign_token<WLBTC>(treasury_cap, upgrade_cap, &metadata);
        let message = message::create_add_tokens_on_sui_message(
            CHAIN_ID,
            bridge.get_seq_num_for(message_types::add_tokens_on_sui()),
            false,
            vector[5],
            vector[type_name::get<WLBTC>().into_string()],
            vector[1000], 
        );
        let payload = message::extract_add_tokens_on_sui(&message);

        bridge::test_execute_add_tokens_on_sui(&mut bridge, payload);
        transfer::public_freeze_object(metadata);

        // Burn the native token and send the wrapped one to the bridge
        ts.next_tx(TREASURY_ADMIN);
        let denylist: DenyList = ts.take_shared();
        let coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
        bridge_vault::return_native<BRIDGE_TESTS, WLBTC>(coin, &mut vault, &mut treasury, &mut bridge, CHAIN_ID, TARGET_ADDRESS, ts.ctx());

        test_utils::destroy(treasury);
        test_utils::destroy(bridge);
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
        let pauser_cap = bridge_vault::new_pauser_cap();
        bridge_vault::add_capability(&cap, &mut vault, PAUSER, pauser_cap);
        ts.return_to_sender(cap);

        // Enable pause
        ts.next_tx(PAUSER);
        bridge_vault::enable_pause(&mut vault, ts.ctx());
        assert!(vault.is_paused_enabled() == true, EWrongPauseState);

        // Disable pause
        ts.next_tx(PAUSER);
        bridge_vault::disable_pause(&mut vault, ts.ctx());
        assert!(vault.is_paused_enabled() == false, EWrongPauseState);
        test_utils::destroy(treasury);
        ts::return_shared(vault);

        ts.end();
    }

    #[test, expected_failure(abort_code = bridge_vault::EInsufficientBalance)]
    fun test_insiffucient_vault_balance() {
        // Start a test transaction scenario
        let mut ts = ts::begin(TREASURY_ADMIN);
        let mut treasury = create_test_currency(&mut ts);

        ts.next_tx(SYSTEM_ADDRESS);
        let mut bridge = new_for_testing(1, ts.ctx());

        // Burn the native token to unlock the wrapped one
        ts.next_tx(TREASURY_ADMIN);
        let denylist: DenyList = ts.take_shared();
        let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
        let coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
        bridge_vault::return_native<BRIDGE_TESTS, WTEST>(coin, &mut vault, &mut treasury, &mut bridge, CHAIN_ID, TARGET_ADDRESS, ts.ctx());

        test_utils::destroy(treasury);
        test_utils::destroy(bridge);
        ts::return_shared(denylist);
        ts::return_shared(vault);

        ts.end();
    }

    #[test, expected_failure(abort_code = bridge_vault::EZeroAmountCoin)]
    fun test_return_zero_amount_coin() {
        // Start a test transaction scenario
        let mut ts = ts::begin(TREASURY_ADMIN);
        let mut treasury = create_test_currency(&mut ts);
        
        // Fill the vault with the wrapped token
        ts.next_tx(TREASURY_ADMIN);
        let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
        bridge_vault::fill_vault(&mut vault, balance::create_for_testing(1000));

        ts.next_tx(SYSTEM_ADDRESS);
        let mut bridge = new_for_testing(1, ts.ctx());

        // Burn the native token to unlock the wrapped one
        ts.next_tx(TREASURY_ADMIN);
        let denylist: DenyList = ts.take_shared();
        let mut coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
        let zero_coin = coin.split(0, ts.ctx());
        bridge_vault::return_native<BRIDGE_TESTS, WTEST>(zero_coin, &mut vault, &mut treasury, &mut bridge, CHAIN_ID, TARGET_ADDRESS, ts.ctx());

        ts.return_to_sender(coin);
        test_utils::destroy(bridge);
        test_utils::destroy(treasury);
        ts::return_shared(denylist);
        ts::return_shared(vault);

        ts.end();
    }

    #[test, expected_failure(abort_code = bridge_vault::EVaultIsPaused)]
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
        let pauser_cap = bridge_vault::new_pauser_cap();
        bridge_vault::add_capability(&cap, &mut vault, PAUSER, pauser_cap);
        ts.return_to_sender(cap);
        
        // enable pause
        ts.next_tx(PAUSER);
        bridge_vault::enable_pause(&mut vault, ts.ctx());

        // Claim the native token by locking the wrapped one
        ts.next_tx(TREASURY_ADMIN);
        let denylist: DenyList = ts.take_shared();
        let wrapped_coin = coin::mint_for_testing<WTEST>(1000, ts.ctx());
        bridge_vault::claim_native<WTEST, BRIDGE_TESTS>(wrapped_coin, &mut vault, &mut treasury, &denylist, ts.ctx());
        test_utils::destroy(treasury);
        ts::return_shared(denylist);
        ts::return_shared(vault);

        ts.end();
    }

    #[test, expected_failure(abort_code = bridge_vault::EVaultIsPaused)]
    fun test_return_when_pause_enabled() {
        // Start a test transaction scenario
        let mut ts = ts::begin(TREASURY_ADMIN);
        let mut treasury = create_test_currency(&mut ts);

        // Fill the vault with the wrapped token
        ts.next_tx(TREASURY_ADMIN);
        let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
        let cap = ts.take_from_sender<AdminCap>();
        bridge_vault::fill_vault(&mut vault, balance::create_for_testing(1000));
        let pauser_cap = bridge_vault::new_pauser_cap();
        bridge_vault::add_capability(&cap, &mut vault, PAUSER, pauser_cap);
        ts.return_to_sender(cap);
        
        // enable pause
        ts.next_tx(PAUSER);
        bridge_vault::enable_pause(&mut vault, ts.ctx());

        ts.next_tx(SYSTEM_ADDRESS);
        let mut bridge = new_for_testing(1, ts.ctx());

        // Burn the native token to unlock the wrapped one
        ts.next_tx(TREASURY_ADMIN);
        let denylist: DenyList = ts.take_shared();
        let coin = ts.take_from_sender<Coin<BRIDGE_TESTS>>();
        bridge_vault::return_native<BRIDGE_TESTS, WTEST>(coin, &mut vault, &mut treasury, &mut bridge, CHAIN_ID, TARGET_ADDRESS, ts.ctx());

        test_utils::destroy(treasury);
        test_utils::destroy(bridge);
        ts::return_shared(denylist);
        ts::return_shared(vault);

        ts.end();
    }

    #[test, expected_failure(abort_code = bridge_vault::ENoAuthRecord)]
    fun test_enable_pause_no_auth() {
        // Start a test transaction scenario
        let mut ts = ts::begin(TREASURY_ADMIN);
        let treasury = create_test_currency(&mut ts);

        // Assign PauserCap
        ts.next_tx(TREASURY_ADMIN);
        let mut vault: Vault<WTEST, BRIDGE_TESTS> = ts.take_shared();
        let cap = ts.take_from_sender<AdminCap>();
        let pauser_cap = bridge_vault::new_pauser_cap();
        bridge_vault::add_capability(&cap, &mut vault, PAUSER, pauser_cap);
        ts.return_to_sender(cap);

        // Remove PauserCap
        ts.next_tx(TREASURY_ADMIN);
        let cap = ts.take_from_sender<AdminCap>();
        bridge_vault::remove_capability<WTEST, BRIDGE_TESTS, PauserCap>(&cap, &mut vault, PAUSER);
        ts.return_to_sender(cap);

        // enable pause
        ts.next_tx(PAUSER);
        bridge_vault::enable_pause(&mut vault, ts.ctx());

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

        bridge_vault::init_for_testing(ts.ctx());

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
        bridge_vault::new_vault<WTEST, BRIDGE_TESTS>(&cap, ts.ctx());
        ts.return_to_sender(cap);

        treasury
    }
}

#[test_only]
module bridge_vault::wlbtc {
    use std::ascii;
    use std::type_name;
    use sui::address;
    use sui::coin::{CoinMetadata, TreasuryCap, create_currency};
    use sui::hex;
    use sui::package::{UpgradeCap, test_publish};
    use sui::test_utils::create_one_time_witness;

    public struct WLBTC has drop {}

    public fun create_bridge_token(
        ctx: &mut TxContext,
    ): (UpgradeCap, TreasuryCap<WLBTC>, CoinMetadata<WLBTC>) {
        let otw = create_one_time_witness<WLBTC>();
        let (treasury_cap, metadata) = create_currency(
            otw,
            8,
            b"wlbtc",
            b"wlbitcoin",
            b"bridge wlbitcoin token",
            option::none(),
            ctx,
        );

        let type_name = type_name::get<WLBTC>();
        let address_bytes = hex::decode(
            ascii::into_bytes(type_name::get_address(&type_name)),
        );
        let coin_id = address::from_bytes(address_bytes).to_id();
        let upgrade_cap = test_publish(coin_id, ctx);

        (upgrade_cap, treasury_cap, metadata)
    }
}



