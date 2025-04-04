// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module lbtc::bitcoin_utils;
/// Enum representing different Bitcoin output types.
public enum OutputType has store, copy, drop {
    Unsupported,
    P2TR,
    P2WPKH,
    P2WSH,
}

/// Constants representing Bitcoin script opcodes.
const OP_0: u8 = 0x00;
const OP_1: u8 = 0x51;
const OP_DATA_32: u8 = 0x20;
const OP_DATA_20: u8 = 0x14;

/// Base spend cost in satoshis.
const BASE_SPEND_COST: u64 = 41;

/// Size of inputs spending different output types.
const NON_WITNESS_INPUT_SIZE: u64 = 107;
const WITNESS_INPUT_SIZE: u64 = 26;

/// Determines the OutputType based on the provided scriptPubkey.
///
/// # Arguments
///
/// * `script_pubkey` - A vector of bytes representing the Bitcoin scriptPubkey.
///
/// # Returns
///
/// * `OutputType` - The determined Bitcoin output type.
public fun get_output_type(script_pubkey: &vector<u8>): OutputType {

    let length = script_pubkey.length();
    
    // Check for P2WPKH
    if (length == 22 && *(script_pubkey.borrow(0)) == OP_0 && *(script_pubkey.borrow(1)) == OP_DATA_20) {
        return OutputType::P2WPKH
        
    };
    // Check for P2TR
    if (length == 34 && *(script_pubkey.borrow(0)) == OP_1 && *(script_pubkey.borrow(1)) == OP_DATA_32) {
        return OutputType::P2TR
    };
    // Check for P2WSH
    if (length == 34 && *(script_pubkey.borrow(0)) == OP_0 && *(script_pubkey.borrow(1)) == OP_DATA_32) {
        return OutputType::P2WSH
    };

    // Unsupported output type
    return OutputType::Unsupported
}


/// Returns the size (in bytes) needed to encode `val` as a variable-length int.
fun var_int_serialize_size(val: u64): u64 {
    if (val < 0xfd) {
        1
    } else if (val <= 0xffff) {
        3
    } else if (val <= 0xffff_ffff) {
        5
    } else {
        9
    }
}

/// Compute the serialized size of a TxOut's scriptPubKey, which is:
///   8 bytes for the value + varint size of the script length + actual script length
fun serialize_size(script_pubkey_len: u64): u64 {
    8
    + var_int_serialize_size(script_pubkey_len)
    + script_pubkey_len
}


/// Computes the dust limit for a given Bitcoin output type.
///
/// The dust limit is the minimum payment to an address that is considered
/// spendable under consensus rules. This calculation is based on Bitcoin Core's
/// implementation.
///
/// # Arguments
///
/// * `out_type` - The Bitcoin output type.
/// * `script_pubkey` - A vector of bytes representing the Bitcoin scriptPubkey.
/// * `dust_fee_rate` - The current dust fee rate (in satoshis per 1000 bytes).
///
/// # Returns
///
/// * `u64` - The calculated dust limit in satoshis.
public fun get_dust_limit_for_output(
    out_type: OutputType,
    script_pubkey: &vector<u8>,
    dust_fee_rate: u64
): u64 {

    let additional_cost: u64;
    if (
        out_type == OutputType::P2TR ||
        out_type == OutputType::P2WPKH ||
        out_type == OutputType::P2WSH
    ) {
        // Witness outputs have a cheaper payment formula
        additional_cost = WITNESS_INPUT_SIZE;
    } else {
        additional_cost = NON_WITNESS_INPUT_SIZE;
    };
    
    let out_size = serialize_size(script_pubkey.length());

    let total_spend_cost: u64 = BASE_SPEND_COST + additional_cost + out_size;

    // Calculate dust limit: (spend_cost * dust_fee_rate) / 1000
    (total_spend_cost * dust_fee_rate) / 1000
}

/// Returns the Unsupported output type.
public fun get_unsupported_output_type(): OutputType {
    OutputType::Unsupported
}

/// Returns the P2TR output type.
public fun get_P2TR_output_type(): OutputType {
    OutputType::P2TR
}

/// Returns the P2WPKH output type.
public fun get_P2WPKH_output_type(): OutputType {
    OutputType::P2WPKH
}

/// Returns the P2WSH output type.
public fun get_P2WSH_output_type(): OutputType {
    OutputType::P2WSH
}
