/// The Timelock Policy is a Move module designed to enforce a delay between successive
/// upgrades of a Sui Move smart contract. This ensures sufficient time for stakeholders
/// to evaluate proposed changes before these are implemented.
///
/// Options for securing the TimelockCap:
/// - Multisig Ownership: Use a multisig address for collaborative control.
/// - Immutable Policy: Permanently enforce the policy by making the UpgradeCap immutable.
///
/// ### Features:
/// - Time-Based Upgrade Locking: Enforces a time delay (24 or 48 hours) before allowing
///   subsequent contract upgrades.
/// - Customizable Delays: Switch between predefined delays (24 or 48 hours).
module timelock_policy::timelock_upgrade;

use sui::package::{UpgradeCap, UpgradeTicket, UpgradeReceipt};

/// Error code for insufficient time elapsed since the last upgrade.
const ENotEnoughTimeElapsed: u64 = 1;
/// Error code for invalid delay values.
const EInvalidDelayValue: u64 = 2;

/// 24 hours in milliseconds.
const MS_24_HOURS: u64 = 24 * 60 * 60 * 1000;
/// 48 hours in milliseconds.
const MS_48_HOURS: u64 = 48 * 60 * 60 * 1000;

/// [Owned] TimelockCap object to enforce time-based delays between contract upgrades.
public struct TimelockCap has key, store {
    id: UID, // Unique ID for the object.
    upgrade_cap: UpgradeCap, // Wrapped UpgradeCap for the target contract.
    last_authorized_time: u64, // Timestamp of the last authorized upgrade.
    delay_ms: u64, // Configured delay in milliseconds (24 or 48 hours).
}

/// Creates a new TimelockCap with the specified delay.
public fun new_timelock(
    upgrade_cap: UpgradeCap,
    delay_ms: u64,
    ctx: &mut TxContext,
): TimelockCap {
    TimelockCap {
        id: object::new(ctx),
        upgrade_cap,
        last_authorized_time: 0,
        delay_ms,
    }
}

/// Authorizes an upgrade if the required delay has passed.
public fun authorize_upgrade(
    timelock: &mut TimelockCap,
    policy: u8,
    digest: vector<u8>,
    ctx: &mut TxContext,
): UpgradeTicket {
    let epoch_start_time_ms = ctx.epoch_timestamp_ms();

    assert!(
        timelock.last_authorized_time == 0 || epoch_start_time_ms >= timelock.last_authorized_time + MS_24_HOURS,
        ENotEnoughTimeElapsed,
    );

    timelock.last_authorized_time = epoch_start_time_ms;

    timelock.upgrade_cap.authorize(policy, digest)
}

/// Commits the upgrade after authorization.
public fun commit_upgrade(timelock: &mut TimelockCap, receipt: UpgradeReceipt) {
    timelock.upgrade_cap.commit(receipt)
}

/// (Irreversible) Makes the TimelockCap immutable, disabling further upgrades.
public fun make_immutable(timelock: TimelockCap) {
    let TimelockCap { id, upgrade_cap, .. } = timelock;
    id.delete();
    upgrade_cap.make_immutable()
}

/// Updates the delay for the TimelockCap.
public fun set_delay(timelock: &mut TimelockCap, delay_ms: u64) {
    assert!(delay_ms == MS_24_HOURS || delay_ms == MS_48_HOURS, EInvalidDelayValue);
    timelock.delay_ms = delay_ms;
}

// === Accessors ===

/// Returns the delay in ms from `TimelockCap`.
public fun delay(self: &TimelockCap): u64 {
    self.delay_ms
}

/// Return the last authorized time in ms from `TimelockCap`.
public fun last_authorized(self: &TimelockCap): u64 {
    self.last_authorized_time
}

#[test_only]
public fun upgrade_cap(self: &TimelockCap): &UpgradeCap {
    &self.upgrade_cap
}
