#[test_only]
module lbtc::multisig_tests;
  use sui::test_scenario::{Self as ts};
    use lbtc::multisig::{derive_multisig_address, is_sender_multisig, ed25519_key_to_address};
 
#[test]
fun test_derive_multisig_address_success() {
    let (pks, weights, threshold) = default_multisig_setup();

    // Attempt to derive the multisig address
    let _multisig_address = derive_multisig_address(pks, weights, threshold);
}

#[test, expected_failure(abort_code = ::lbtc::multisig::ELengthsOfPksAndWeightsAreNotEqual)]
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
    let invalid_pk = vector[1, 2, 3, 4]; // Invalid key (does not start with 0x00)

    // Attempt to convert invalid key
    let _address = ed25519_key_to_address(&invalid_pk);
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
    // Example public keys for multisig signers
    let key1: vector<u8> = vector[
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
        117,
    ]; // ED25519
    let key2: vector<u8> = vector[
        1,
        2,
        14,
        23,
        205,
        89,
        57,
        228,
        107,
        25,
        102,
        65,
        150,
        140,
        215,
        89,
        145,
        11,
        162,
        87,
        126,
        39,
        250,
        115,
        253,
        227,
        135,
        109,
        185,
        190,
        197,
        188,
        235,
        43,
    ]; // Secp256k1
    let key3: vector<u8> = vector[
        2,
        3,
        71,
        251,
        175,
        35,
        240,
        56,
        171,
        196,
        195,
        8,
        162,
        113,
        17,
        122,
        42,
        76,
        255,
        174,
        221,
        188,
        95,
        248,
        28,
        117,
        23,
        188,
        108,
        116,
        167,
        237,
        180,
        48,
    ]; // Secp256r1

    // Combine keys into a vector
    let pks: vector<vector<u8>> = vector[key1, key2, key3];

    // Assign weights for each key
    let weights: vector<u8> = vector[1, 1, 1];

    // Define a threshold
    let threshold: u16 = 2;

    (pks, weights, threshold)
}
