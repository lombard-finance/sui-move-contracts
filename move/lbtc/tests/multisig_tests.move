#[test_only]
module lbtc::multisig_tests;

use lbtc::multisig::{
    derive_multisig_address,
    is_sender_multisig,
    ed25519_key_to_address,
    secp256k1_key_to_address,
    secp256r1_key_to_address
};
use sui::test_scenario as ts;

#[test]
fun test_derive_multisig_address_success() {
    let (pks, weights, threshold) = default_multisig_setup();

    // Attempt to derive the multisig address
    let _multisig_address = derive_multisig_address(pks, weights, threshold);
}

#[
    test,
    expected_failure(
        abort_code = ::lbtc::multisig::ELengthsOfPksAndWeightsAreNotEqual,
    ),
]
fun test_derive_multisig_address_mismatched_lengths() {
    let (pks, weights, threshold) = default_multisig_setup();
    // Remove one weight to cause mismatch
    let mut weights_mismatched = weights;
    vector::pop_back(&mut weights_mismatched);
    // Attempt to derive the multisig address
    let _multisig_address = derive_multisig_address(pks, weights_mismatched, threshold);
}

#[test, expected_failure(abort_code = ::lbtc::multisig::EThresholdOutOfBounds)]
fun test_derive_multisig_address_invalid_threshold_zero() {
    let (pks, weights, _) = default_multisig_setup();

    // Set threshold to zero
    let threshold = 0;

    // Attempt to derive the multisig address
    let _multisig_address = derive_multisig_address(pks, weights, threshold);
}

#[test, expected_failure(abort_code = ::lbtc::multisig::EThresholdOutOfBounds)]
fun test_derive_multisig_address_threshold_exceeds_weights() {
    let (pks, weights, _) = default_multisig_setup();

    // Sum of weights is 3; set threshold to 4
    let threshold = 4;

    // Attempt to derive the multisig address
    let _multisig_address = derive_multisig_address(pks, weights, threshold);
}

#[test, expected_failure(abort_code = ::lbtc::multisig::EInvalidPublicKey)]
fun test_ed25519_key_to_address_invalid_key() {
    let invalid_pk = get_key_secpk1();
    // Attempt to convert invalid key
    let _address = ed25519_key_to_address(&invalid_pk);
}

#[test]
fun test_ed25519_key_to_address_success() {
    let valid_pk = get_key_ed25519();
    // Attempt to convert valid key
    let _address = ed25519_key_to_address(&valid_pk);
}

#[test, expected_failure(abort_code = ::lbtc::multisig::EInvalidPublicKey)]
fun test_secp256k1_key_to_address_invalid_key() {
    let invalid_pk = get_key_secpr1();
    // Attempt to convert invalid key
    let _address = secp256k1_key_to_address(&invalid_pk);
}

#[test]
fun test_secp256k1_key_to_address_success() {
    let valid_pk = get_key_secpk1();
    // Attempt to convert valid key
    let _address = secp256k1_key_to_address(&valid_pk);
}

#[test, expected_failure(abort_code = ::lbtc::multisig::EInvalidPublicKey)]
fun test_secp256r1_key_to_address_invalid_key() {
    let invalid_pk = get_key_secpk1();
    // Attempt to convert invalid key
    let _address = secp256r1_key_to_address(&invalid_pk);
}

#[test]
fun test_secp256r1_key_to_address_success() {
    let valid_pk = get_key_secpr1();
    // Attempt to convert valid key
    let _address = secp256r1_key_to_address(&valid_pk);
}

#[test]
fun test_is_sender_multisig_success() {
    let mut ts = ts::begin(@0x0);
    let (pks, weights, threshold) = default_multisig_setup();

    let multisig_address = derive_multisig_address(pks, weights, threshold);

    // Simulate a transaction from the multisig address
    ts.next_tx(multisig_address);
    let is_multisig = is_sender_multisig(pks, weights, threshold, ts.ctx());
    assert!(is_multisig);

    ts.end();
}

#[test]
fun test_is_sender_multisig_failure() {
    let mut ts = ts::begin(@0x0);
    let (pks, weights, threshold) = default_multisig_setup();

    let non_multisig_address = @0x1;

    // Simulate a transaction from a different address
    ts.next_tx(non_multisig_address);
    let is_multisig = is_sender_multisig(pks, weights, threshold, ts.ctx());
    assert!(!is_multisig);

    ts.end();
}

#[test_only]
public fun default_multisig_setup(): (vector<vector<u8>>, vector<u8>, u16) {
    let (key1, key2, key3) = (get_key_ed25519(), get_key_secpk1(), get_key_secpr1());

    // Combine keys into a vector
    let pks: vector<vector<u8>> = vector[key1, key2, key3];

    // Assign weights for each key
    let weights: vector<u8> = vector[1, 1, 1];

    // Define a threshold
    let threshold: u16 = 2;

    (pks, weights, threshold)
}

#[test_only]
public fun get_key_ed25519(): vector<u8> {
    vector[
        0,
        13,
        125,
        171,
        53,
        140,
        141,
        173,
        170,
        78,
        250,
        0,
        73,
        167,
        91,
        7,
        67,
        101,
        85,
        177,
        10,
        54,
        130,
        25,
        187,
        104,
        15,
        112,
        87,
        19,
        73,
        215,
        3,
    ]
}

#[test_only]
// Secp256k1 (prefix 0x02 or 0x01)
public fun get_key_secpk1(): vector<u8> {
    vector[
        1,
        2,
        74,
        241,
        195,
        136,
        28,
        121,
        15,
        59,
        179,
        42,
        51,
        94,
        92,
        133,
        218,
        1,
        98,
        186,
        91,
        86,
        49,
        125,
        165,
        223,
        222,
        122,
        24,
        108,
        114,
        149,
        216,
        9,
    ]
}

#[test_only]
public fun get_key_secpr1(): vector<u8> {
    vector[
        2,
        2,
        74,
        241,
        195,
        136,
        28,
        121,
        15,
        59,
        179,
        42,
        51,
        94,
        92,
        133,
        218,
        1,
        98,
        186,
        91,
        86,
        49,
        125,
        165,
        223,
        222,
        122,
        24,
        108,
        114,
        149,
        216,
        9,
    ]
}
