// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module for working with multisig addresses, including utilities
/// for deriving, validating, and checking the sender against a multisig address.
///
/// ### Features:
/// - Derive multisig addresses from public keys, weights, and a threshold.
/// - Validate whether the sender is a multisig address.
/// - Support for key types such as Ed25519, Secp256k1, and Secp256r1.
///
/// ### Errors:
/// - `ELengthsOfPksAndWeightsAreNotEqual`: Length mismatch between public keys and
/// weights.
/// - `EThresholdOutOfBounds`: Invalid threshold, must be > 0 and ≤ sum of weights.
/// - `EInvalidPublicKey`: Public key format or type is invalid.
module lbtc::multisig;

use lbtc::pk_util;
use sui::address;
use sui::bcs;
use sui::hash::blake2b256;

/// Error indicating that the lengths of public keys and weights are not equal.
const ELengthsOfPksAndWeightsAreNotEqual: u64 = 0;

/// Error indicating that the threshold is out of bounds.
const EThresholdOutOfBounds: u64 = 1;

/// Error indicating that a public key is invalid.
const EInvalidPublicKey: u64 = 2;

// === Multisig Address Derivation ===

/// Derives a multisig address from public keys, weights, and a threshold.
public fun derive_multisig_address(
    pks: vector<vector<u8>>,
    weights: vector<u8>,
    threshold: u16,
): address {
    let multi_sig_flag: u8 = 0x03; // Multisig flag identifier.
    let mut hash_data = vector<u8>[];

    let pks_len = pks.length();
    let weights_len = weights.length();

    // Validate lengths of public keys and weights.
    assert!(pks_len == weights_len, ELengthsOfPksAndWeightsAreNotEqual);

    // Validate threshold.
    let mut sum: u16 = 0;
    let mut i = 0;
    while (i < weights_len) {
        sum = sum + (weights[i] as u16);
        i = i + 1;
    };
    assert!(threshold > 0 && threshold <= sum, EThresholdOutOfBounds);

    // Serialize multisig flag and threshold into hash data.
    hash_data.push_back(multi_sig_flag);
    hash_data.append(bcs::to_bytes(&threshold));

    // Serialize public keys and weights into hash data.
    i = 0;
    while (i < pks_len) {
        hash_data.append(pks[i]);
        hash_data.push_back(weights[i]);
        i = i + 1;
    };

    // Generate and return the multisig address.
    address::from_bytes(blake2b256(&hash_data))
}

/// Checks if the transaction sender is a multisig address derived from the provided
/// public keys, weights, and threshold.
public fun is_sender_multisig(
    pks: vector<vector<u8>>,
    weights: vector<u8>,
    threshold: u16,
    ctx: &TxContext,
): bool {
    let derived_address = derive_multisig_address(pks, weights, threshold);
    derived_address == ctx.sender()
}

// === Public Key to Address Conversion ===

/// Converts an Ed25519 public key to an address.
public fun ed25519_key_to_address(pk: &vector<u8>): address {
    address_from_bytes(pk, 0x00)
}

/// Converts a Secp256k1 public key to an address.
public fun secp256k1_key_to_address(pk: &vector<u8>): address {
    address_from_bytes(pk, 0x01)
}

/// Converts a Secp256r1 public key to an address.
public fun secp256r1_key_to_address(pk: &vector<u8>): address {
    address_from_bytes(pk, 0x02)
}

// === Internal ===

/// Converts a public key to an address based on its type, with validation for length and prefix.
fun address_from_bytes(pk: &vector<u8>, flag: u8): address {
    assert!(pk_util::is_valid_key(pk), EInvalidPublicKey);
    assert!(pk[0] == flag, EInvalidPublicKey);
    address::from_bytes(blake2b256(pk))
}
