// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Helper functions for public key schema validation.
module lbtc::pk_util;

const EPublicKeyVectorCannotBeEmpty: u64 = 0;
const EInvalidPublicKey: u64 = 1;

public enum KeyType {
    Ed25519,
    Secp256k1,
    Secp256r1,
    Invalid,
}

/// Validates a signature.
public fun validate_signature(user_signature: vector<u8>, public_key: vector<u8>, message: &vector<u8>): bool {
    // Since the key will contain a prefix for ID purposes, we need to chop it off to verify properly.
    let mut chopped_pk = vector::empty();
    let mut i = 1;
    while (i < public_key.length()) {
        chopped_pk.push_back(public_key[i]);
        i = i + 1;
    };

    match (get_key_type(&public_key)) {
        KeyType::Ed25519 => sui::ed25519::ed25519_verify(&user_signature, &chopped_pk, message),
        KeyType::Secp256k1 => sui::ecdsa_k1::secp256k1_verify(&user_signature, &chopped_pk, message, 1),
        KeyType::Secp256r1 => sui::ecdsa_r1::secp256r1_verify(&user_signature, &chopped_pk, message, 1),
        KeyType::Invalid => false,
    }
}

/// Validates the public key vector and each public key within.
///
/// Ensures the vector is non-empty and all public keys are valid for supported cryptographic types:
/// - Ed25519 (32 bytes, prefix 0x00)
/// - Secp256k1/Secp256r1 compressed (33 bytes, prefix 0x02 or 0x03)
/// - Secp256k1/Secp256r1 uncompressed (65 bytes)
public fun validate_pks(pks: &vector<vector<u8>>) {
    // Ensure the vector is non-empty
    assert!(pks.length() > 0, EPublicKeyVectorCannotBeEmpty);

    // Iterate through the public keys and validate
    let mut i = 0;
    while (i < pks.length()) {
        assert!(is_valid_key(pks.borrow(i)), EInvalidPublicKey);
        i = i + 1;
    };
}

/// Helper function to check if a public key is valid for Ed25519, Secp256k1, or Secp256r1.
public(package) fun is_valid_key(pk: &vector<u8>): bool {
    let prefix = *pk.borrow(0);

    match (pk.length()) {
        // Ed25519 (32 bytes plus prefix 0x00)
        33 => prefix == 0,
        // Secp256k1 or Secp256r1 (33 bytes plus prefix 0x01 or 0x02)
        34 => prefix == 1 || prefix == 2,
        // Invalid length
        _ => false,
    }
}

fun get_key_type(pk: &vector<u8>): KeyType {
    let prefix = *pk.borrow(0);

    match (pk.length()) {
        // Ed25519 (32 bytes plus prefix 0x00)
        33 => if (prefix == 0) { KeyType::Ed25519 } else { KeyType::Invalid },
        // Secp256k1 or Secp256r1 (33 bytes plus prefix 0x01 or 0x02)
        34 => {
            if (prefix == 1) {
                KeyType::Secp256k1
            } else if (prefix == 2) {
                KeyType::Secp256r1
            } else {
                KeyType::Invalid
            }
        },
        // Invalid length
        _ => KeyType::Invalid,
    }
}
