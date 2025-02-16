/// Module: bascule
module bascule::bascule;

use std::ascii::String;
use std::type_name;
use sui::bcs;
use sui::event;
use sui::hash::keccak256;
use sui::package;
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};

/** ************************ Capabilities ************************ **/

/// The OTW (One Time Witness) for the module.
public struct BASCULE has drop {}

/// The capability of the bascule owner.
public struct BasculeOwnerCap has key, store { id: UID }

/// The capability of the bascule pauser.
public struct BasculePauserCap has key, store { id: UID }

/// The capability of the bascule reporter.
public struct BasculeReporterCap has key, store { id: UID }

/** NOTE: Unlike our Solidity contract, we do not have a separate guardian
* role/capability. Unlike Ethereum, with PTBs, an external caller can execute
* multiple functions in a single transaction, so the two step process of
* granting guardian capability to increase threshold/unpause the contract is
* not meaningful. */

/** ************************ Errors ************************ **/

/// Contract is paused.
const EPaused: u64 = 0;

/// This account is not allowed to validate withdrawals
const ENotValidator: u64 = 1;

/// The deposit has already been withdrawn.
const EAlreadyWithdrawn: u64 = 2;

/// The withdrawal amount is not in the history above the non-zero validation threshold.
const EWithdrawalFailedValidation: u64 = 3;

/** ************************ Events ************************ **/

/// Event emitted when the validation threshold is updated.
public struct UpdateValidateThreshold has copy, drop { old_threshold: u64, new_threshold: u64 }

/// Event emitted when deposit was successfully reported.
public struct DepositReported has copy, drop { deposit_id: u256 }

/// Event emitted when reporting an already reported/withdrawn deposit.
public struct AlreadyReported has copy, drop { deposit_id: u256, status: DepositState }

/// Event emitted when a withdrawal is allowed on this chain without validation.
public struct WithdrawalNotValidated has copy, drop { deposit_id: u256, amount: u64 }

/// Event emitted when a withdrawal is validated.
public struct WithdrawalValidated has copy, drop { deposit_id: u256, amount: u64 }

/** ************************ Bascule ************************ **/

public struct Bascule has key {
    id: UID,
    /// Is the contract paused
    mIsPaused: bool,
    /// The types of the contract witnesses that are allowed to validate withdrawals.
    /// We use an allow list of stringified types instead of capabilities to
    /// decouple the deployment of Bascule from the LBTC contract.
    /// The Sui semantics ensure that types are uniquely serialized to Strings
    /// and cannot be forged.
    mWithdrawalValidators: VecSet<String>,
    /// Bascule validates all withdrawals whose amounts are greater than or equal
    /// to this threshold. The bascule allows all withdrawals below this threshold.
    /// The contract will still produce events that off-chain code can use to
    /// monitor smaller withdrawals.
    ///
    /// When the threshold is zero (the default), the bascule validates all
    /// withdrawals.
    mValidateThreshold: u64,
    /// Mapping that tracks deposits on a different chain that can be used to
    /// withdraw the corresponding funds on this chain.
    /// Unlike maps in Solidity, tables are real maps so the lack of an entry in
    /// the map means a deposit is not (yet) reported.
    ///
    /// NOTE: The deposit identifier (key) should be a hash with enough
    /// information to uniquely identify the deposit transaction on the source
    /// chain and the recipient, amount, and chain-id on this chain.
    /// See README for more.
    mDepositHistory: Table<u256, DepositState>,
}

// Describes the state of a deposit in the depositHistory.
public enum DepositState has copy, drop, store {
    Reported,
    Withdrawn,
}

/// Get the state of a deposit in the deposit history.
public fun get_deposit_state(bascule: &Bascule, deposit_id: u256): Option<DepositState> {
    if (bascule.mDepositHistory.contains(deposit_id)) {
        option::some(*bascule.mDepositHistory.borrow(deposit_id))
    } else {
        option::none<DepositState>()
    }
}

/// Returns true if the deposit has not been reported.
public fun deposit_is_unreported(bascule: &Bascule, deposit_id: u256): bool {
    bascule.get_deposit_state(deposit_id).is_none()
}

/// Returns true if the deposit has been reported but not yet withdrawn.
/// NOTE: This function returns false if the report was reported but withdrawn;
/// `deposit_is_unreported` on the other hand returns true only if the deposit was never reported
public fun deposit_is_reported(bascule: &Bascule, deposit_id: u256): bool {
    bascule.get_deposit_state(deposit_id).is_some_and!(|s| s.is_reported())
}

/// Returns true if the deposit has been withdrawn.
public fun deposit_is_withdrawn(bascule: &Bascule, deposit_id: u256): bool {
    bascule.get_deposit_state(deposit_id).is_some_and!(|s| s.is_withdrawn())
}

/// Returns true if the deposit has been reported.
public fun is_reported(state: &DepositState): bool {
    state == &DepositState::Reported
}

/// Returns true if the deposit has been withdrawn.
public fun is_withdrawn(state: &DepositState): bool {
    state == &DepositState::Withdrawn
}

#[test_only]
/// Wrapper of module initializer for testing
public fun test_init(ctx: &mut TxContext) {
    init(BASCULE {}, ctx);
}

/// Module initializer
fun init(otw: BASCULE, ctx: &mut TxContext) {
    // Claim package
    package::claim_and_keep(otw, ctx);
    // Create the Bascule object.
    let bascule = Bascule {
        id: object::new(ctx),
        mIsPaused: false,
        mWithdrawalValidators: vec_set::empty<String>(),
        mValidateThreshold: 0,
        mDepositHistory: table::new<u256, DepositState>(ctx),
    };
    // Grant the caller the owner and pauser capabilities.
    // The owner can then:
    // - grant the reporter capability to another account (i.e., off-chain Bascule reporter)
    // - add the witness structs that can be used to validate withdrawals (i.e., LBTC account)
    transfer::transfer(
        BasculeOwnerCap {
            id: object::new(ctx),
        },
        tx_context::sender(ctx),
    );
    transfer::transfer(
        BasculePauserCap {
            id: object::new(ctx),
        },
        tx_context::sender(ctx),
    );
    transfer::share_object(bascule);
}

/** ************************ Pause ************************ **/

/// Get the pause state of the contract.
public fun is_paused(bascule: &Bascule): bool {
    bascule.mIsPaused
}

/// Create new pauser capability and grant it to the specified account.
entry fun grant_pauser(_: &BasculeOwnerCap, pauser: address, ctx: &mut TxContext) {
    transfer::transfer(
        BasculePauserCap {
            id: object::new(ctx),
        },
        pauser,
    );
}

/// Pause contract.
#[allow(lint(prefer_mut_tx_context))]
public fun pause(_: &BasculePauserCap, bascule: &mut Bascule, _ctx: &TxContext) {
    bascule.mIsPaused = true;
}

/// Unpause contract.
#[allow(lint(prefer_mut_tx_context))]
public fun unpause(_: &BasculePauserCap, bascule: &mut Bascule, _ctx: &TxContext) {
    bascule.mIsPaused = false;
}

/// Assert that the contract is not paused.
fun assert_not_paused(bascule: &Bascule) {
    assert!(!bascule.mIsPaused, EPaused);
}

/** ************************ Report ************************ **/

/// Create new reporter capability and grant it to the specified account.
entry fun grant_reporter(_: &BasculeOwnerCap, reporter: address, ctx: &mut TxContext) {
    transfer::transfer(
        BasculeReporterCap {
            id: object::new(ctx),
        },
        reporter,
    );
}

/// Report a single deposit.
// Reporting an already-reported deposit does nothing. This simplifies the
// off-chain code that reports deposits.
// We don't implement a batch-reporting function because SUI has PTBs that can
// be used to call this function multiple times in a single transaction.
entry fun report_deposit(
    _: &BasculeReporterCap,
    bascule: &mut Bascule,
    deposit_id: u256,
    _ctx: &TxContext,
) {
    assert_not_paused(bascule);

    let status = bascule.get_deposit_state(deposit_id);

    if (status.is_none()) {
        // not yet reported
        bascule.mDepositHistory.add(deposit_id, DepositState::Reported);
        event::emit(DepositReported { deposit_id });
    } else {
        status.do!(|status| {
            event::emit(AlreadyReported { deposit_id, status });
        })
    }
}

/** ************************ Validate withdrawal ************************ **/

/// Get the threshold amount above which validation is required.
public fun get_validate_threshold(bascule: &Bascule): u64 {
    bascule.mValidateThreshold
}

/// Update the threshold for withdrawals that require validation.
// This function can only be called by the owner and doesn't use the two-step
// guardian approach we use in the Solidity contract (largely for simplicity).
entry fun update_validate_threshold(
    _: &BasculeOwnerCap,
    bascule: &mut Bascule,
    new_threshold: u64,
    _ctx: &TxContext,
) {
    assert_not_paused(bascule);
    let old_threshold = bascule.mValidateThreshold;
    bascule.mValidateThreshold = new_threshold;
    event::emit(UpdateValidateThreshold { old_threshold, new_threshold });
}

/// Assert that the type is a withdrawal validator.
fun assert_is_validator(bascule: &Bascule, validator_type: String) {
    assert!(bascule.is_validator(validator_type), ENotValidator);
}

/// Add a withdrawal validator to the list of witness types that are allowed to validate withdrawals.
/// We use an access control list instead of capabilities for the validator because we want to
/// (1) make the integration for LBTC simpler -- they just need to call this function by passing a
/// witness struct and (2) be able to revoke the privilege to validate withdrawals.
entry fun add_withdrawal_validator(
    _: &BasculeOwnerCap,
    bascule: &mut Bascule,
    validator_type: String,
    _ctx: &TxContext,
) {
    vec_set::insert(&mut bascule.mWithdrawalValidators, validator_type);
}

/// Remove a withdrawal validator from the list of witness types that are allowed to validate withdrawals.
entry fun remove_withdrawal_validator(
    _: &BasculeOwnerCap,
    bascule: &mut Bascule,
    validator_type: String,
    _ctx: &TxContext,
) {
    vec_set::remove(&mut bascule.mWithdrawalValidators, &validator_type);
}

/// Returns whether the witness type is a withdrawal validator.
public fun is_validator(bascule: &Bascule, validator_type: String): bool {
    vec_set::contains(&bascule.mWithdrawalValidators, &validator_type)
}

/// Validate a withdrawal if the amount is above the threshold.
/// Trivially allow all withdrawals below the threshold.
//
/// This function checks if our accounting has recorded a deposit that
/// corresponds to this withdrawal request. A deposit can only be withdrawn
/// once.
#[allow(lint(prefer_mut_tx_context))]
public fun validate_withdrawal<T: drop>(
    _witness: T,
    bascule: &mut Bascule,
    to: address,
    amount: u64,
    tx_id: vector<u8>,
    index: u32,
) {
    let witness_type = type_name::get<T>();
    assert_is_validator(bascule, witness_type.into_string());
    assert_not_paused(bascule);

    // Compute the deposit id from inputs
    let deposit_id = to_deposit_id(to, amount, tx_id, index);

    // Get report if any
    let status: Option<DepositState> = bascule.get_deposit_state(deposit_id);

    // Deposit found and not withdrawn
    if (status.is_some_and!(|s| !s.is_withdrawn())) {
        let state = bascule.mDepositHistory.borrow_mut(deposit_id);
        *state = DepositState::Withdrawn;
        event::emit(WithdrawalValidated { deposit_id, amount });
    } else {
        // Ensure the deposit is not withdrawn
        assert!(!status.is_some_and!(|s| s.is_withdrawn()), EAlreadyWithdrawn);

        // At this point: We don't have the deposit_id in the mDepositHistory

        // Ensure the amount is less than the threshold (i.e., allow withdrawals below
        // threshold otherwise fail with validation error)
        assert!(amount < bascule.mValidateThreshold, EWithdrawalFailedValidation);
        // Withdrawal is below the threshold, so we allow the withdrawal without
        // additional on-chain validation.
        // Still, we record the withdrawal in the deposit history.
        bascule.mDepositHistory.add(deposit_id, DepositState::Withdrawn);

        event::emit(WithdrawalNotValidated { deposit_id, amount });
    }
}

/// Compute the deposit id from the to address, tx_id, index, and amount.
// For EVM chains, we compute the deposit id as the keccak256 hash of ABI encoded:
// - u256(chain-id) || to(address) || u256(amount) || fixed-bytes32(tx-id) || u256(index)
// For SUI, we compute the deposit id as the keccak256 hash of BCS encoded:
// - fixed-bytes32(0x00) || 0x03, 0x53, 0x55, 0x49 || to(address) || fixed-bytes32(tx-id) || u32(index)
// Bascule does not allow chain-id to be 0 for EVM chains to ensure unique
// prefix for SUI and EVM chains.
fun to_deposit_id(to: address, amount: u64, tx_id: vector<u8>, index: u32): u256 {
    let mut hash_data = vector<u8>[];
    // 32-bytes zero as prefix (to ensure unique prefix for SUI and EVM chains)
    hash_data.append(bcs::to_bytes(&0u256)); // CODESYNC(non-evm-prefix)
    // 4-bytes unique id for SUI (can be interpreted as: lengh(3) || "SUI")
    // This lets us use the zero prefix with chains other than SUI as long as
    // this id is unique
    hash_data.append(vector<u8>[0x03, 0x53, 0x55, 0x49]); // CODESYNC(sui-unique-id)
    // Transaction details, BCS encoded
    // The encoding is described https://github.com/diem/bcs#binary-canonical-serialization-bcs
    hash_data.append(to.to_bytes());
    hash_data.append(bcs::to_bytes(&amount));
    hash_data.append(tx_id);
    hash_data.append(bcs::to_bytes(&index));
    let hash = keccak256(&hash_data);
    bcs::new(hash).peel_u256()
}

#[test_only]
/// Wrapper for computing deposit id for testing
public fun test_to_deposit_id(to: address, amount: u64, tx_id: vector<u8>, index: u32): u256 {
    to_deposit_id(to, amount, tx_id, index)
}