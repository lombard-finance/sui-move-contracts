// Module which simulates the bascule contract
// To be deleted when the real bascule contract is deployed
module bascule::bascule;

use std::{
    ascii::String,
    type_name::Self
};

const EInvalidWitness: u64 = 0;

public struct Bascule has key {
    id: UID,
    accepted: vector<String>
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(Bascule {
        id: object::new(ctx),
        accepted: vector::empty()
    });
}

public fun whitelist_witness(
    bascule: &mut Bascule,
    witness_type: String
) {
    vector::push_back(&mut bascule.accepted, witness_type);
}

public fun validate_withdrawal<T: drop>(
    _witness: T,
    bascule: &mut Bascule,
    to: address,
    amount: u64,
    tx_id: vector<u8>,
    index: u32,
) {
    let witness_type = type_name::get<T>();
    assert!(bascule.accepted.contains(&witness_type.into_string()), EInvalidWitness);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
