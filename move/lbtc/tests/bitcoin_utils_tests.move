#[test_only]
module lbtc::bitcoin_utils_tests;

use lbtc::bitcoin_utils::{
    get_output_type, get_dust_limit_for_output, get_unsupported_output_type, get_P2WSH_output_type, 
    get_P2TR_output_type, get_P2WPKH_output_type,
};

/// Constants representing Bitcoin script opcodes.
const OP_0: u8 = 0x00;
const OP_1: u8 = 0x51;
const OP_DATA_32: u8 = 0x20;
const OP_DATA_20: u8 = 0x14;

// === Test Constants ===
const DUST_FEE_RATE_LOW: u64 = 100;     // Example low fee rate
const DUST_FEE_RATE_HIGH: u64 = 100000; // Example high fee rate
const DUST_FEE_RATE_ZERO: u64 = 0;      // Zero fee rate

/// Test `get_output_type` with a valid P2WPKH scriptPubKey.
#[test]
public fun test_get_output_type_p2wpkh() {
    let opcodes: vector<u8> = vector[OP_0, OP_DATA_20];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8];
    let mut script_pubkey: vector<u8> = opcodes;
    vector::append(&mut script_pubkey, pubkey);
    
    let output_type = get_output_type(&script_pubkey);
    assert!(output_type == get_P2WPKH_output_type(), 1001);
}

/// Test `get_output_type` with a valid P2TR scriptPubKey.
#[test]
public fun test_get_output_type_p2tr() {
    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8, 2u8,
                                    2u8, 2u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;
    
    let output_type = get_output_type(&script_pubkey);
    assert!(output_type == get_P2TR_output_type(), 1002);
}

/// Test `get_output_type` with a valid P2WSH scriptPubKey.
#[test]
public fun test_get_output_type_p2wsh() {
    let opcodes: vector<u8> = vector[OP_0, OP_DATA_32];
    let pubkey: vector<u8> = vector[3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8,
                                    3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8,
                                    3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8, 3u8,
                                    3u8, 3u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    let output_type = get_output_type(&script_pubkey);
    assert!(output_type == get_P2WSH_output_type(), 1003);
}

/// Test `get_output_type` with an unsupported scriptPubKey.
#[test]
public fun test_get_output_type_unsupported() {
    let opcodes: vector<u8> = vector[OP_1, OP_DATA_20];
    let pubkey: vector<u8> = vector[4u8, 4u8, 4u8, 4u8, 4u8, 4u8, 4u8, 4u8, 4u8, 4u8,
                                    4u8, 4u8, 4u8, 4u8, 4u8, 4u8, 4u8, 4u8, 4u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    let output_type = get_output_type(&script_pubkey);
    assert!(output_type == get_unsupported_output_type(), 1004);
}

/// Test `get_dust_limit_for_output` with P2WPKH and a low dust fee rate.
#[test]
public fun test_get_dust_limit_p2wpkh_low_fee() {
    let out_type = get_P2WPKH_output_type();
    let opcodes: vector<u8> = vector[OP_0, OP_DATA_20];
    let pubkey: vector<u8> = vector[
        7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8,
        7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8
    ];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    let dust_fee_rate = DUST_FEE_RATE_LOW; // presumably 100
    let dust_limit = get_dust_limit_for_output(out_type, &script_pubkey, dust_fee_rate);

    // total_spend_cost = 98
    // dust_limit       = (98 * 100) / 1000 = 9
    let expected_dust_limit: u64 = 9;
    assert!(dust_limit == expected_dust_limit, 1007);
}


/// Test `get_dust_limit_for_output` with P2TR and a high dust fee rate.
#[test]
public fun test_get_dust_limit_p2tr_high_fee() {
    let out_type = get_P2TR_output_type();
    let opcodes: vector<u8> = vector[OP_1, OP_DATA_32];
    let pubkey: vector<u8> = vector[
        8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8,
        8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8,
        8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8, 8u8,
        8u8, 8u8
    ];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    let dust_fee_rate = DUST_FEE_RATE_HIGH; // presumably 100000
    let dust_limit = get_dust_limit_for_output(out_type, &script_pubkey, dust_fee_rate);

    // total_spend_cost = 110
    // dust_limit       = (110 * 100000) / 1000 = 11000
    let expected_dust_limit: u64 = 11000;
    assert!(dust_limit == expected_dust_limit, 1008);
}


/// Test `get_dust_limit_for_output` with Unsupported OutputType.
#[test]
public fun test_get_dust_limit_unsupported() {
    let out_type = get_unsupported_output_type();
    let opcodes: vector<u8> = vector[OP_DATA_20];
    let pubkey: vector<u8> = vector[
        9u8, 9u8, 9u8, 9u8, 9u8, 9u8, 9u8, 9u8, 9u8, 9u8,
        9u8, 9u8, 9u8, 9u8, 9u8, 9u8, 9u8, 9u8, 9u8, 9u8
    ];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    let dust_fee_rate = DUST_FEE_RATE_LOW; // presumably 100
    let dust_limit = get_dust_limit_for_output(out_type, &script_pubkey, dust_fee_rate);

    // total_spend_cost = 178
    // dust_limit       = (178 * 100) / 1000 = 17
    let expected_dust_limit: u64 = 17;
    assert!(dust_limit == expected_dust_limit, 1009);
}


/// Test `get_dust_limit_for_output` with zero dust fee rate.
#[test]
public fun test_get_dust_limit_zero_fee_rate() {
    let out_type = get_P2WPKH_output_type();
    let opcodes: vector<u8> = vector[OP_0, OP_DATA_20];
    let pubkey: vector<u8> = vector[10u8, 10u8, 10u8, 10u8, 10u8, 10u8, 10u8, 10u8, 10u8, 10u8,
                                    10u8, 10u8, 10u8, 10u8, 10u8, 10u8, 10u8, 10u8, 10u8, 10u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    let dust_fee_rate = DUST_FEE_RATE_ZERO;
    let dust_limit = get_dust_limit_for_output(out_type, &script_pubkey, dust_fee_rate);

    let expected_dust_limit: u64 = 0u64;
    assert!(dust_limit == expected_dust_limit, 1010);
}

/// Test `get_unsupported_output_type` function.
#[test]
public fun test_get_unsupported_output_type() {
    let unsupported = get_unsupported_output_type();
    assert!(unsupported == get_unsupported_output_type(), 1012);
}

/// Test `get_dust_limit_for_output` with an invalid scriptPubKey length for P2WPKH.
#[test]
public fun test_get_dust_limit_p2wpkh_invalid_length() {
    let out_type = get_P2WPKH_output_type();
    let opcodes: vector<u8> = vector[OP_0, OP_DATA_20];
    // Only 19 bytes of 12u8 instead of the required 20
    let pubkey: vector<u8> = vector[
        12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8,
        12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8
    ];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    // Suppose DUST_FEE_RATE_LOW = 100
    let dust_fee_rate = DUST_FEE_RATE_LOW;

    let dust_limit = get_dust_limit_for_output(out_type, &script_pubkey, dust_fee_rate);

    // Manually compute expected dust limit for length = 21
    // out_size = 8 + 1 + 21 = 30
    // total_spend_cost = 41 + 26 + 30 = 97
    // dust_limit = (97 * 100) / 1000 = 9
    let expected_dust_limit: u64 = 9;

    assert!(dust_limit == expected_dust_limit, 1013);
}

/// Test `get_dust_limit_for_output` with a scriptPubKey that exactly matches the expected length.
#[test]
public fun test_get_dust_limit_exact_length() {
    let out_type = get_P2WSH_output_type();
    let opcodes: vector<u8> = vector[OP_0, OP_DATA_32];
    // Exactly 32 bytes of 13u8
    let pubkey: vector<u8> = vector[
        13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8,
        13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8,
        13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8, 13u8,
        13u8, 13u8
    ];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    // Suppose DUST_FEE_RATE_LOW = 100
    let dust_fee_rate = DUST_FEE_RATE_LOW;

    let dust_limit = get_dust_limit_for_output(out_type, &script_pubkey, dust_fee_rate);

    // For length = 34
    // out_size = 8 + 1 + 34 = 43
    // total_spend_cost = 41 + 26 + 43 = 110
    // dust_limit = (110 * 100) / 1000 = 11
    let expected_dust_limit: u64 = 11;

    assert!(dust_limit == expected_dust_limit, 1014);
}

/// Test `get_dust_limit_for_output` with a non-standard scriptPubKey.
#[test]
public fun test_get_dust_limit_non_standard_script() {
    let out_type = get_unsupported_output_type();
    let opcodes: vector<u8> = vector[OP_DATA_20];
    let pubkey: vector<u8> = vector[
        14u8, 14u8, 14u8, 14u8, 14u8, 14u8, 14u8, 14u8, 14u8, 14u8,
        14u8, 14u8, 14u8, 14u8, 14u8, 14u8, 14u8, 14u8, 14u8, 14u8
    ];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    // Suppose DUST_FEE_RATE_LOW = 100
    let dust_fee_rate = DUST_FEE_RATE_LOW;
    let dust_limit = get_dust_limit_for_output(out_type, &script_pubkey, dust_fee_rate);

    // total_spend_cost = 41 + 107 + 30 = 178
    // dust_limit = (178 * 100) / 1000 = 17
    let expected_dust_limit: u64 = 17;
    assert!(dust_limit == expected_dust_limit, 1015);
}

#[test]
public fun test_bitcoin_lib_dust_limit_equivalence() {
    let out_type = get_P2WPKH_output_type();
    let opcodes: vector<u8> = vector[OP_0, OP_DATA_20];
    let pubkey: vector<u8> = vector[12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8,
                                    12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8];
    let mut combined: vector<u8> = opcodes;
    vector::append(&mut combined, pubkey);
    let script_pubkey: vector<u8> = combined;

    let dust_limit = get_dust_limit_for_output(out_type, &script_pubkey, 3000);
    std::debug::print(&dust_limit);
    assert!(dust_limit == 294);
}
