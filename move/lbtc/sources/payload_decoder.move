#[deprecated(note = b"Not valid")]
module lbtc::payload_decoder;

use sui::bcs::{Self, BCS};

const EDeprecated: u64 = 9999;

public fun decode_fee_payload(_payload: vector<u8>): (u32, u256, u256) {
    abort EDeprecated
}

public fun decode_valset(_payload: vector<u8>): (
    u32, 
    u256, 
    vector<vector<u8>>, 
    vector<u256>, 
    u256
) {
    abort EDeprecated
}

public fun decode_signatures(_proof: vector<u8>): vector<vector<u8>> {
    abort EDeprecated
}

public fun decode_mint_payload(_payload: vector<u8>): (u32, u256, address, u256, u256, u256) {
    abort EDeprecated
}
