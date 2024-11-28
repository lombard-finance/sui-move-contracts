#[test_only]
module timelock_policy::policy_tests;

use sui::hash;
use sui::package;
use sui::test_scenario as ts;
use sui::test_utils;
use timelock_policy::timelock_upgrade;

/// 24 hours in milliseconds.
const MS_24_HOURS: u64 = 24 * 60 * 60 * 1000;
/// 48 hours in milliseconds.
const MS_48_HOURS: u64 = 48 * 60 * 60 * 1000;

/// Test creating a TimelockCap
#[test]
fun test_create_timelock_cap() {
    let mut ts = ts::begin(@0x1);

    // Simulate publishing a package
    let upgrade_cap = package::test_publish(@0x42.to_id(), ts.ctx());

    // Create a TimelockCap with a 24-hour delay
    let timelock = timelock_upgrade::new_timelock(
        upgrade_cap,
        MS_24_HOURS,
        ts.ctx(),
    );

    // Validate TimelockCap properties
    assert!(timelock.delay() == MS_24_HOURS, 1);
    assert!(timelock.last_authorized() == 0, 2);

    test_utils::destroy(timelock);
    ts.end();
}

/// Test setting the delay on a TimelockCap
#[test]
fun test_set_timelock_delay() {
    let mut ts = ts::begin(@0x1);

    // Simulate publishing a package and creating a TimelockCap
    let upgrade_cap = package::test_publish(@0x42.to_id(), ts.ctx());
    let mut timelock = timelock_upgrade::new_timelock(
        upgrade_cap,
        MS_24_HOURS,
        ts.ctx(),
    );

    // Update the delay to 48 hours
    timelock_upgrade::set_delay(&mut timelock, MS_48_HOURS);

    // Validate the updated delay
    assert!(timelock.delay() == MS_48_HOURS, 3);

    test_utils::destroy(timelock);
    ts.end();
}

/// Test authorizing an upgrade
#[test]
fun test_authorize_upgrade() {
    let mut ts = ts::begin(@0x1);

    // Simulate publishing a package and creating a TimelockCap
    let upgrade_cap = package::test_publish(@0x42.to_id(), ts.ctx());
    let mut timelock = timelock_upgrade::new_timelock(
        upgrade_cap,
        MS_24_HOURS,
        ts.ctx(),
    );

    // Create a digest for the upgrade
    let digest = hash::blake2b256(&b"package contents");

    // Authorize an upgrade
    let ticket = timelock_upgrade::authorize_upgrade(
        &mut timelock,
        package::compatible_policy(),
        digest,
        ts.ctx(),
    );

    // Validate the ticket
    assert!(package::ticket_policy(&ticket) == package::compatible_policy(), 4);
    assert!(package::ticket_digest(&ticket) == &digest, 5);

    test_utils::destroy(timelock);
    test_utils::destroy(ticket);
    ts.end();
}

/// Test committing an upgrade
#[test]
fun test_commit_upgrade() {
    let mut ts = ts::begin(@0x1);

    // Simulate publishing a package and creating a TimelockCap
    let upgrade_cap = package::test_publish(@0x42.to_id(), ts.ctx());
    let mut timelock = timelock_upgrade::new_timelock(
        upgrade_cap,
        MS_24_HOURS,
        ts.ctx(),
    );

    // Authorize and simulate an upgrade
    let digest = hash::blake2b256(&b"package contents");
    let ticket = timelock_upgrade::authorize_upgrade(
        &mut timelock,
        package::compatible_policy(),
        digest,
        ts.ctx(),
    );
    let receipt = package::test_upgrade(ticket);

    // Commit the upgrade
    timelock_upgrade::commit_upgrade(&mut timelock, receipt);

    // Validate the upgrade
    assert!(package::upgrade_package(timelock.upgrade_cap()) != @0x42.to_id(), 6);

    test_utils::destroy(timelock);
    ts.end();
}

/// Test failure to set an invalid delay
#[test]
#[expected_failure(abort_code = timelock_upgrade::EInvalidDelayValue)]
fun test_failure_set_invalid_delay() {
    let mut ts = ts::begin(@0x1);

    // Simulate publishing a package and creating a TimelockCap
    let upgrade_cap = package::test_publish(@0x42.to_id(), ts.ctx());
    let mut timelock = timelock_upgrade::new_timelock(
        upgrade_cap,
        MS_24_HOURS,
        ts.ctx(),
    );

    // Attempt to set an invalid delay
    timelock_upgrade::set_delay(&mut timelock, 12345);

    test_utils::destroy(timelock);
    ts.end();
}
