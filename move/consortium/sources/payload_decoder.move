/// Module: payload_decoder
module consortium::payload_decoder;

use std::hash;
use sui::bcs::{Self, BCS};
use sui::ecdsa_k1;

const EHashMismatch: u64 = 0;

public fun decode_signatures(payload: vector<u8>): vector<vector<u8>> {
    let mut signatures = vector::empty<vector<u8>>();
    let mut b = bcs::new(payload);
    let _ = decode_left_padded_u256(&mut b); // initial offset, can be discarded
    let length = decode_left_padded_u256(&mut b);
    let offset = decode_left_padded_u256(&mut b); // bytes to chop off minus 32 to arrive at the first element
    let middle = offset - 32;

    if (middle > 0) {
        let mut rem = middle;
        while (rem != 0) {
            let _ = bcs::peel_u8(&mut b);
            rem = rem - 1;
        };
    };

    let mut i = 0;
    while (i < length) {
        // We always read 64 bytes, but the ABI encoding will give this as metadata anyway, so
        // we should chop it off first.
        let _ = bcs::peel_u256(&mut b);

        let r = bcs::peel_u256(&mut b);
        let s = bcs::peel_u256(&mut b);
        let mut signature = vector::empty<u8>();
        signature.append(bcs::to_bytes(&r));
        signature.append(bcs::to_bytes(&s));
        signatures.push_back(signature);
        i = i + 1;
    };

    signatures
}

public fun validate_signatures(
    signers: vector<vector<u8>>,
    signatures: vector<vector<u8>>, 
    message: vector<u8>, 
    hash: vector<u8>
): bool {
    // First, ensure hash is correct wrt message
    let message_hash = hash::sha2_256(message);
    assert!(message_hash == hash, EHashMismatch);

    // Now, for each signature, check correctness.
    let mut i = 0;
    while (i < signatures.length()) {
        // We need to append the v, which is either 27 or 28.
        let mut sig = signatures[i];
        sig.push_back(0u8);

        // Hash function is set to 1 (sha256), since:
        // ecdsa_k1::SHA256: u8 = 1;
        // We can't reference this however so we need to use the magic value.
        let recovered = ecdsa_k1::secp256k1_ecrecover(
            &sig, 
            &message, 
            1
        );

        // If that didn't work, we try v = 28.
        if (recovered != signers[i]) {
            let _ = sig.pop_back();
            sig.push_back(1u8);
            let recovered = ecdsa_k1::secp256k1_ecrecover(
                &sig, 
                &message, 
                1
            );

            if (recovered != signers[i]) {
                return false
            };
        };

        i = i + 1;
    };

    true
}

public fun decode(payload: vector<u8>): (u32, u256, address, u256, u256, u256) {
    let mut b = bcs::new(payload);
    (
        decode_be_u32(&mut b), decode_left_padded_u256(&mut b), 
        bcs::peel_address(&mut b), decode_left_padded_u256(&mut b), 
        decode_left_padded_u256(&mut b), decode_left_padded_u256(&mut b)
    )
}

fun decode_be_u32(payload: &mut BCS): u32 {
    let mut rem = 4;
    let mut bytes = vector::empty<u8>();
    while (rem != 0) {
        let byte = bcs::peel_u8(payload);
        bytes.push_back(byte);
        rem = rem - 1;
    };

    let mut ret = 0u32;
    let mut i = 0;
    while (i < bytes.length()) {
        let casted = (bytes[i] as u32) << (((3 - i) as u8) * 8);
        ret = ret | casted;
        i = i + 1;
    };

    ret
}

fun decode_left_padded_u256(payload: &mut BCS): u256 {
    let mut rem = 32;
    let mut bytes = vector::empty<u8>();
    let mut consumed_padding = false;
    while (rem != 0) {
        let byte = bcs::peel_u8(payload);
        if (!consumed_padding) {
            if (byte != 0u8) {
                consumed_padding = true;
                bytes.push_back(byte);
            }
        } else {
            bytes.push_back(byte);
        };

        rem = rem - 1;
    };

    let mut ret = 0u256;
    let mut i = 0;
    while (i < bytes.length()) {
        let casted = (bytes[i] as u256) << ((((bytes.length() - 1) - i) as u8) * 8);
        ret = ret | casted;
        i = i + 1;
    };

    ret
}

