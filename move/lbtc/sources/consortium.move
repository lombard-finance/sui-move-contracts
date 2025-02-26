#[deprecated(note = b"Not valid")]
module lbtc::consortium;

use std::hash;
use sui::ecdsa_k1;
use sui::table::{Self, Table};
use lbtc::payload_decoder;

const EDeprecated: u64 = 9999;

public struct Consortium has key {
    id: UID,
    epoch: u256,
    validator_set: Table<u256, ValidatorSet>,
    valset_action: u32,
    admins: vector<address>,
}

public struct ValidatorSet has store {
    pub_keys: vector<vector<u8>>,
    weights: vector<u256>,
    weight_threshold: u256,
}

public fun validate_payload(
    _consortium: &mut Consortium,
    _payload: vector<u8>,
    _proof: vector<u8>,
) {
    abort EDeprecated
}

public fun set_next_validator_set(
    _consortium: &mut Consortium,
    _payload: vector<u8>,
    _proof: vector<u8>,
) {
    abort EDeprecated
}

public fun set_initial_validator_set(
    _consortium: &mut Consortium,
    _payload: vector<u8>,
    _ctx: &mut TxContext,
) {
    abort EDeprecated
}

public fun set_valset_action(
    _consortium: &mut Consortium,
    _valset_action: u32,
    _ctx: &mut TxContext,
) {
    abort EDeprecated
}

public fun add_admin(
    _consortium: &mut Consortium,
    _new_admin: address,
    _ctx: &mut TxContext,
) {
    abort EDeprecated
}

public fun remove_admin(
    _consortium: &mut Consortium,
    _admin: address,
    _ctx: &mut TxContext,
) {
    abort EDeprecated
}

public fun get_validator_set(_consortium: &Consortium, _epoch: u256): &ValidatorSet {
    abort EDeprecated
}

public fun get_epoch(_consortium: &Consortium): u256 {
    abort EDeprecated
}

public fun validate_signatures(
    _signers: vector<vector<u8>>,
    _signatures: vector<vector<u8>>,
    _weights: vector<u256>,
    _weight_threshold: u256, 
    _message: vector<u8>, 
    _hash: vector<u8>
): bool {
    abort EDeprecated
}


