/// Module: payload_decoder
module consortium::payload_decoder;

use sui::bcs::{Self, BCS};

const EInvalidPayloadLength: u64 = 1;

public fun decode_valset(payload: vector<u8>): (
    u32, 
    u256, 
    vector<vector<u8>>, 
    vector<u256>, 
    u256, 
    u256
) {
    let mut b = bcs::new(payload);
    let action = decode_be_u32(&mut b);
    let epoch = decode_left_padded_u256(&mut b);

    // Valset will decode two offsets here to be discarded
    let _ = bcs::peel_u256(&mut b);
    let _ = bcs::peel_u256(&mut b);

    let weight_threshold = decode_left_padded_u256(&mut b);
    let height = decode_left_padded_u256(&mut b);
    let validators = decode_valset_array(&mut b);
    let weights = decode_u256_array(&mut b);

    assert!(b.into_remainder_bytes().length() == 0, EInvalidPayloadLength);

    (action, epoch, validators, weights, weight_threshold, height)
}

public fun decode_signatures(payload: vector<u8>): vector<vector<u8>> {
    let mut b = bcs::new(payload);
    decode_bytes_array(&mut b)
}

public fun decode_mint_payload(payload: vector<u8>): (u32, u256, address, u256, u256, u256) {
    let mut b = bcs::new(payload);
    (
        decode_be_u32(&mut b), decode_left_padded_u256(&mut b), 
        bcs::peel_address(&mut b), decode_left_padded_u256(&mut b), 
        decode_left_padded_u256(&mut b), decode_left_padded_u256(&mut b)
    )
}

// Convenience function which recovers the bytes of array elements.
fun decode_bytes_array(b: &mut BCS): vector<vector<u8>> {
    let _ = decode_left_padded_u256(b); // initial offset, can be discarded
    let length = decode_left_padded_u256(b);
    let offset = decode_left_padded_u256(b); // bytes to chop off minus 32 to arrive at the first element
    let middle = offset - 32;

    if (middle > 0) {
        let mut rem = middle;
        while (rem != 0) {
            let _ = bcs::peel_u8(b);
            rem = rem - 1;
        };
    };

    let mut items = vector::empty<vector<u8>>();
    let mut i = 0;
    while (i < length) {
        let item_length = decode_left_padded_u256(b);
        let mut ret = vector::empty<u8>();
        let mut j = 0;
        while (j < item_length) {
            let byte = bcs::peel_u8(b);
            ret.push_back(byte);
            j = j + 1;
        };

        items.push_back(ret);
        i = i + 1;
    };

    items
}

fun decode_valset_array(b: &mut BCS): vector<vector<u8>> {
    let length = decode_left_padded_u256(b);
    let mut offset = decode_left_padded_u256(b);
    offset = offset - 32; // The offset accounts for its own slot.

    while (offset != 0) {
        let _ = bcs::peel_u8(b);
        offset = offset - 1;
    };

    let mut items = vector::empty<vector<u8>>();
    let mut i = 0;
    while (i < length) {
        let item_length = decode_left_padded_u256(b);
        let mut ret = vector::empty<u8>();
        let mut j = 0;
        while (j < item_length) {
            let byte = bcs::peel_u8(b);
            ret.push_back(byte);
            j = j + 1;
        };

        items.push_back(ret);

        // Clear any leftover bytes.
        while (j % 32 != 0) {
            let _ = bcs::peel_u8(b);
            j = j + 1;
        };

        i = i + 1;
    };

    items
}

fun decode_u256_array(b: &mut BCS): vector<u256> {
    let length = decode_left_padded_u256(b);
    let mut items = vector::empty<u256>();
    let mut i = 0;
    while (i < length) {
        let item = decode_left_padded_u256(b);
        items.push_back(item);
        i = i + 1;
    };

    items
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

