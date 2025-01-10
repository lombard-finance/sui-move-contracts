module consortium::consortium;

use std::hash;
use sui::table::{Self, Table};
use consortium::payload_decoder;

/// Sender is unauthorized.
const EUnauthorized: u64 = 0;
/// Admin already exists.
const EAdminAlreadyExists: u64 = 1;
/// Admin does not exist.
const EAdminDoesNotExist: u64 = 2;
/// Payload has already been used.
const EUsedPayload: u64 = 3;
/// Invalid payload.
const EInvalidPayload: u64 = 4;
/// Admin vector should contain at least one address.
const ECannotRemoveLastAdmin: u64 = 5;
/// Validator set does not exist for the given epoch.
const EValidatorSetDoesNotExist: u64 = 6;
/// Validator set has already been initialized.
const EAlreadyInitialized: u64 = 7;
/// Invalid action.
const EInvalidAction: u64 = 8;
/// Invalid validator set size.
const EInvalidValidatorSetSize: u64 = 9;
/// Invalid threshold.
const EInvalidThreshold: u64 = 10;
/// Invalid validators and weights.
const EInvalidValidatorsAndWeights: u64 = 11;
/// Weights cannot be zero.
const EZeroWeight: u64 = 12;
/// Weights are lower than the threshold.
const EWeightsLowerThanThreshold: u64 = 13;
/// Epoch is invalid.
const EInvalidEpoch: u64 = 14;
/// Payload length is invalid.
const EInvalidPayloadLength: u64 = 15;

// === Constants ===
const NEW_VALSET: u32 = 1252728175;
const MIN_VALIDATOR_SET_SIZE: u64 = 1;
const MAX_VALIDATOR_SET_SIZE: u64 = 102;

public struct ValidateProof has drop {
    hash: vector<u8>,
}

/// Consortium struct which contains the current epoch, the public keys of the validator,
/// the used payloads and the admin addresses 
public struct Consortium has key {
    id: UID,
    epoch: u256,
    validator_set: Table<u256, ValidatorSet>,
    used_payloads: Table<vector<u8>, bool>,
    admins: vector<address>,
}

/// ValidatorSet struct which contains the public keys of the validators, the weights of the validators, and the threshold
public struct ValidatorSet has store {
    pub_keys: vector<vector<u8>>,
    weights: vector<u256>,
    weight_threshold: u256,
}

fun init(ctx: &mut TxContext) {
    let consortium = Consortium {
        id: object::new(ctx),
        epoch: 0,
        validator_set: table::new<u256, ValidatorSet>(ctx),
        used_payloads: table::new<vector<u8>, bool>(ctx),
        admins: vector::singleton(ctx.sender()),
    };
    transfer::share_object(consortium);
}

/// Validates that the payload has not been used and that the signatures are valid.
/// ValidateProof contains the hash of the payload if the payload is valid.
public fun validate_payload(
    consortium: &Consortium,
    payload: vector<u8>,
    proof: vector<u8>,
): ValidateProof {
    // Payload should consist of 164 bytes (160 for message and 4 for the action)
    assert!(payload.length() == 164, EInvalidPayloadLength);
    let hash = hash::sha2_256(payload);
    assert!(!consortium.is_payload_used(hash), EUsedPayload);
    // get the signatures from the proof
    let signatures = payload_decoder::decode_signatures(proof);
    // get the validator set for the current epoch
    let signers = consortium.get_validator_set(consortium.epoch);
    assert!(payload_decoder::validate_signatures(signers.pub_keys, signatures, signers.weights, signers.weight_threshold, payload, hash), EInvalidPayload);
    ValidateProof { hash }
}

/// Resolves the ValidateProof by adding the hash to the used_payloads table.
public fun resolve_proof(
    consortium: &mut Consortium,
    proof: ValidateProof,
) {
    let ValidateProof { hash } = proof;
    consortium.used_payloads.add(hash, true);
}

// Increments the epoch and updates the validator set.
public fun set_next_validator_set(
    consortium: &mut Consortium,
    payload: vector<u8>,
    proof: vector<u8>,
) {
    let hash = hash::sha2_256(payload);
    // get the signature from the proof
    let signatures = payload_decoder::decode_signatures(proof);
    // get the validator set for the current epoch
    let signers = consortium.get_validator_set(consortium.epoch);
    assert!(payload_decoder::validate_signatures(signers.pub_keys, signatures, signers.weights, signers.weight_threshold, payload, hash), EInvalidPayload);

    // get the new validator set from the payload and do all the checks
    let (action, epoch, validators, weights, weight_threshold, _height) = payload_decoder::decode_valset(payload);
    assert!(epoch == consortium.epoch + 1, EInvalidEpoch);
    assert_validator_set(action, validators, weights, weight_threshold);
    consortium.epoch = epoch;
    consortium.validator_set.add(
        epoch, 
        ValidatorSet {
            pub_keys: validators,
            weights,
            weight_threshold,
        }
    );
}

// === Admin Functions ===

// Set initial validator set.
// This function is only callable by admin and can only be called once.
public fun set_initial_validator_set(
    consortium: &mut Consortium,
    payload: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(consortium.admins.contains(&ctx.sender()), EUnauthorized);
    // To set the initial validator set, the epoch should be 0.
    // Since we assume that the initial validator set will have epoch > 0 to match the other chains,
    // we are safe that this function will only be called once
    assert!(consortium.epoch == 0, EAlreadyInitialized);
    let (action, epoch, validators, weights, weight_threshold, _height) = payload_decoder::decode_valset(payload);
    assert!(!consortium.validator_set.contains(epoch), EInvalidEpoch);
    assert_validator_set(action, validators, weights, weight_threshold);
    consortium.epoch = epoch;
    consortium.validator_set.add(
        epoch, 
        ValidatorSet {
            pub_keys: validators,
            weights,
            weight_threshold,
        }
    );
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
    assert!(consortium.admins.length() > 1, ECannotRemoveLastAdmin);
    let (exists, index) = consortium.admins.index_of(&admin);
    assert!(exists, EAdminDoesNotExist);
    consortium.admins.remove(index);
}

// === Utilities ===

/// Get the validator set for a given epoch.
public fun get_validator_set(consortium: &Consortium, epoch: u256): &ValidatorSet {
    assert!(consortium.validator_set.contains(epoch), EValidatorSetDoesNotExist);
    consortium.validator_set.borrow(epoch)
}

/// Check if the payload has been used.
public fun is_payload_used(consortium: &Consortium, hash: vector<u8>): bool {
    consortium.used_payloads.contains(hash)
}

/// Get the current epoch
public fun get_epoch(consortium: &Consortium): u256 {
    consortium.epoch
}

// === Private Functions ===
fun assert_validator_set(
    actions: u32,
    validators: vector<vector<u8>>,
    weights: vector<u256>,
    weight_threshold: u256,
) {
    assert!(actions == NEW_VALSET, EInvalidAction);
    assert!(validators.length() >= MIN_VALIDATOR_SET_SIZE, EInvalidValidatorSetSize);
    assert!(validators.length() <= MAX_VALIDATOR_SET_SIZE, EInvalidValidatorSetSize);
    assert!(weight_threshold > 0, EInvalidThreshold);
    assert!(validators.length() == weights.length(), EInvalidValidatorsAndWeights);
    let mut i = 0;
    let mut sum = 0;
    while (i < weights.length()) {
        assert!(weights[i] > 0, EZeroWeight);
        sum = sum + weights[i];
        i = i + 1;
    };
    assert!(sum >= weight_threshold, EWeightsLowerThanThreshold);
}

// === Test Functions ===
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}


