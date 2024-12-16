// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Helper functions for public key schema validation.
module consortium::pk_utils;

const EPubliKeyVectorCannotBeEmpty: u64 = 0;
const EInvalidPublicKey: u64 = 1;

/// Validates the public key vector and each public key within.
///
/// Ensures the vector is non-empty and all public keys are valid for supported cryptographic types:
/// - Ed25519 (32 bytes, prefix 0x00)
/// - Secp256k1/Secp256r1 compressed (33 bytes, prefix 0x02 or 0x03)
/// - Secp256k1/Secp256r1 uncompressed (65 bytes)
public fun validate_pks(pks: &vector<vector<u8>>) {
    // Ensure the vector is non-empty
    assert!(pks.length() > 0, EPubliKeyVectorCannotBeEmpty);

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