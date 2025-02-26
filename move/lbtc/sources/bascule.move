#[deprecated(note = b"Not valid")]
module lbtc::bascule;

use std::ascii::String;
use std::type_name;
use sui::bcs;
use sui::event;
use sui::hash::keccak256;
use sui::package;
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};

const EDeprecated: u64 = 9999;

public struct BASCULE has drop {}

public struct BasculeOwnerCap has key, store { id: UID }

public struct BasculePauserCap has key, store { id: UID }

public struct BasculeReporterCap has key, store { id: UID }

public struct UpdateValidateThreshold has copy, drop { old_threshold: u64, new_threshold: u64 }

public struct DepositReported has copy, drop { deposit_id: u256 }

public struct AlreadyReported has copy, drop { deposit_id: u256, status: DepositState }

public struct WithdrawalNotValidated has copy, drop { deposit_id: u256, amount: u64 }

public struct WithdrawalValidated has copy, drop { deposit_id: u256, amount: u64 }

public struct Bascule has key {
    id: UID,
    mIsPaused: bool,
    mWithdrawalValidators: VecSet<String>,
    mValidateThreshold: u64,
    mDepositHistory: Table<u256, DepositState>,
}

public enum DepositState has copy, drop, store {
    Reported,
    Withdrawn,
}

public fun get_deposit_state(_bascule: &Bascule, _deposit_id: u256): Option<DepositState> {
    abort EDeprecated
}

public fun deposit_is_unreported(_bascule: &Bascule, _deposit_id: u256): bool {
    abort EDeprecated
}

public fun deposit_is_reported(_bascule: &Bascule, _deposit_id: u256): bool {
    abort EDeprecated
}

public fun deposit_is_withdrawn(_bascule: &Bascule, _deposit_id: u256): bool {
    abort EDeprecated
}

public fun is_reported(_state: &DepositState): bool {
    abort EDeprecated
}

public fun is_withdrawn(state: &DepositState): bool {
    abort EDeprecated
}

public fun is_paused(_bascule: &Bascule): bool {
    abort EDeprecated
}

#[allow(lint(prefer_mut_tx_context))]
public fun pause(_: &BasculePauserCap, _bascule: &mut Bascule, _ctx: &TxContext) {
    abort EDeprecated
}

#[allow(lint(prefer_mut_tx_context))]
public fun unpause(_: &BasculePauserCap, _bascule: &mut Bascule, _ctx: &TxContext) {
    abort EDeprecated
}

public fun get_validate_threshold(_bascule: &Bascule): u64 {
    abort EDeprecated
}

public fun is_validator(_bascule: &Bascule, _validator_type: String): bool {
    abort EDeprecated
}

#[allow(lint(prefer_mut_tx_context))]
public fun validate_withdrawal<T: drop>(
    _witness: T,
    _bascule: &mut Bascule,
    _to: address,
    _amount: u64,
    _tx_id: vector<u8>,
    _index: u32,
) {
    abort EDeprecated
}
