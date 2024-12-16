module consortium::consortium;

use std::hash;
use sui::table::{Self, Table};
use consortium::pk_utils;
use consortium::payload_decoder;

/// Sender is unauthorized.
const EUnauthorized: u64 = 0;
/// Admin already exists.
const EAdminAlreadyExists: u64 = 1;
/// Admin does not exist.
const EAdminDoesNotExist: u64 = 2;
/// Payload has already been used.
const EUsedPayload: u64 = 3;

/// Consortium struct which contains the current epoch, the public keys of the validator,
/// the used payloads and the admin addresses 
public struct Consortium has key {
    id: UID,
    epoch: u64,
    validator_set: Table<u64, vector<vector<u8>>>,
    used_payloads: Table<vector<u8>, bool>,
    admins: vector<address>,
}

fun init(ctx: &mut TxContext) {
    let consortium = Consortium {
        id: object::new(ctx),
        epoch: 0,
        validator_set: table::new<u64, vector<vector<u8>>>(ctx),
        used_payloads: table::new<vector<u8>, bool>(ctx),
        admins: vector::singleton(ctx.sender()),
    };
    transfer::share_object(consortium);
}

/// Validates that the payload has not been used and that the signatures are valid.
/// If the payload is valid, it is stored onchain and marked as used.
public fun validate_payload(
    consortium: &mut Consortium,
    payload: vector<u8>,
    proof: vector<u8>,
): bool {
    let hash = hash::sha2_256(payload);
    assert!(!consortium.is_payload_used(hash), EUsedPayload);
    let signatures = payload_decoder::decode_signatures(proof);
    let signers = consortium.get_validator_set();
    if (payload_decoder::validate_signatures(signers, signatures, payload, hash)) {
        consortium.used_payloads.add(hash, true);
        true
    } else {
        false
    }
}

// === Admin ===
// Increments the epoch and updates the validator set.
public fun set_next_validator_set(
    consortium: &mut Consortium,
    new_validator_set: vector<vector<u8>>,
    ctx: &mut TxContext,
) {
    assert!(consortium.admins.contains(&ctx.sender()), EUnauthorized);
    pk_utils::validate_pks(&new_validator_set);
    consortium.epoch = consortium.epoch + 1;
    consortium.validator_set.add(consortium.epoch, new_validator_set);
}

// Adds a new admin.
public fun add_admin(
    consortium: &mut Consortium,
    new_admin: address,
    ctx: &mut TxContext,
) {
    assert!(consortium.admins.contains(&ctx.sender()), EUnauthorized);
    assert!(!consortium.admins.contains(&new_admin), EAdminAlreadyExists);
    consortium.admins.push_back(new_admin);
}

// Removes an admin.
public fun remove_admin(
    consortium: &mut Consortium,
    admin: address,
    ctx: &mut TxContext,
) {
    assert!(consortium.admins.contains(&ctx.sender()), EUnauthorized);
    let (exists, index) = consortium.admins.index_of(&admin);
    assert!(exists, EAdminDoesNotExist);
    consortium.admins.remove(index);
}

// === Utilities ===

/// Get the latest validator set.
public fun get_validator_set(consortium: &Consortium): vector<vector<u8>> {
    *consortium.validator_set.borrow(consortium.epoch)
}

/// Check if the hash of the payload has been used.
public fun is_payload_used(consortium: &Consortium, payload: vector<u8>): bool {
    consortium.used_payloads.contains(hash::sha2_256(payload))
}


