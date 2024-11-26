#[test_only]
module lbtc::multisig_tests;

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
