import Foundation
import Testing
@testable import TilerCore

// Keep Awake session state machine (power spec). Pure decision core: the clock and
// battery are injected, effects are returned for the system layer to perform. Every
// bullet in the implementation brief's semantics list maps to at least one case here.
@Suite("Power policy FSM") struct PowerPolicyTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1000)

    // MARK: start

    @Test func startWhileOffAcquiresIndefinite() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        let effects = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(effects == [.acquire(AssertionSpec(displayAwake: false, systemSleepBlock: false))])
        #expect(policy.isActive)
        #expect(!policy.clamshell)
        #expect(policy.deadline == nil)
        #expect(policy.remaining(now: t0) == nil)   // indefinite
    }

    @Test func startTimedSetsDeadlineAndRemaining() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        let effects = policy.handle(.start(clamshell: false, duration: 1800), now: t0)
        #expect(effects == [.acquire(AssertionSpec(displayAwake: false, systemSleepBlock: false))])
        #expect(policy.deadline == t0.addingTimeInterval(1800))
        #expect(policy.remaining(now: t0.addingTimeInterval(600)) == 1200)
    }

    @Test func startDisplayAwakeMirrorsSetting() {
        var policy = PowerPolicy(displayAwake: true, floorPercent: 20)
        let effects = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(effects == [.acquire(AssertionSpec(displayAwake: true, systemSleepBlock: false))])
    }

    @Test func startClamshellAcquiresAndArms() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        let effects = policy.handle(.start(clamshell: true, duration: 3600), now: t0)
        #expect(effects == [
            .acquire(AssertionSpec(displayAwake: false, systemSleepBlock: true)),
            .armClamshell(deadline: t0.addingTimeInterval(3600)),
        ])
        #expect(policy.clamshell)
    }

    // MARK: replacement (start while active)

    @Test func replacementNonToNon() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        let effects = policy.handle(.start(clamshell: false, duration: 7200), now: t0)
        #expect(effects == [
            .release(.user),
            .acquire(AssertionSpec(displayAwake: false, systemSleepBlock: false)),
        ])
        #expect(policy.deadline == t0.addingTimeInterval(7200))
    }

    @Test func replacementClamshellToClamshell() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: true, duration: nil), now: t0)
        let effects = policy.handle(.start(clamshell: true, duration: 7200), now: t0)
        #expect(effects == [
            .disarmClamshell,
            .release(.user),
            .acquire(AssertionSpec(displayAwake: false, systemSleepBlock: true)),
            .armClamshell(deadline: t0.addingTimeInterval(7200)),
        ])
    }

    @Test func replacementNonToClamshellArmsButDoesNotDisarm() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        let effects = policy.handle(.start(clamshell: true, duration: nil), now: t0)
        #expect(effects == [
            .release(.user),
            .acquire(AssertionSpec(displayAwake: false, systemSleepBlock: true)),
            .armClamshell(deadline: nil),
        ])
    }

    @Test func replacementClamshellToNonDisarmsButDoesNotArm() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: true, duration: nil), now: t0)
        let effects = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(effects == [
            .disarmClamshell,
            .release(.user),
            .acquire(AssertionSpec(displayAwake: false, systemSleepBlock: false)),
        ])
        #expect(!policy.clamshell)
    }

    // MARK: stop

    @Test func stopReleasesAndGoesOff() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        let effects = policy.handle(.stop, now: t0)
        #expect(effects == [.release(.user)])
        #expect(!policy.isActive)
        #expect(policy.remaining(now: t0) == nil)
    }

    @Test func stopClamshellDisarmsFirst() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: true, duration: nil), now: t0)
        let effects = policy.handle(.stop, now: t0)
        #expect(effects == [.disarmClamshell, .release(.user)])
    }

    @Test func stopWhileOffNoEffect() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        #expect(policy.handle(.stop, now: t0) == [])
    }

    // MARK: tick / expiry

    @Test func tickNoEffectBeforeDeadlineIndefiniteOrOff() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        #expect(policy.handle(.tick, now: t0) == [])                    // off
        _ = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(policy.handle(.tick, now: t0.addingTimeInterval(9999)) == [])  // indefinite
        _ = policy.handle(.start(clamshell: false, duration: 1800), now: t0)
        #expect(policy.handle(.tick, now: t0.addingTimeInterval(600)) == [])   // before deadline
    }

    @Test func tickPastDeadlineExpires() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: false, duration: 1800), now: t0)
        let effects = policy.handle(.tick, now: t0.addingTimeInterval(1801))
        #expect(effects == [.release(.expired)])
        #expect(!policy.isActive)
    }

    @Test func tickPastDeadlineClamshellDisarms() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: true, duration: 1800), now: t0)
        let effects = policy.handle(.tick, now: t0.addingTimeInterval(1801))
        #expect(effects == [.disarmClamshell, .release(.expired)])
    }

    // MARK: battery floor

    @Test func floorStopOnBatteryNotifies() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        let effects = policy.handle(.power(PowerStatus(percent: 20, onBattery: true)), now: t0)
        #expect(effects == [.release(.batteryFloor), .notifyFloorStop(percent: 20)])
        #expect(!policy.isActive)
    }

    @Test func floorKeepsRunningOnACAtSameCharge() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        let effects = policy.handle(.power(PowerStatus(percent: 15, onBattery: false)), now: t0)
        #expect(effects == [])
        #expect(policy.isActive)
    }

    @Test func floorOffNilAndAbovePercentDoNotStop() {
        // floor Off never stops
        var off = PowerPolicy(displayAwake: false, floorPercent: 0)
        _ = off.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(off.handle(.power(PowerStatus(percent: 5, onBattery: true)), now: t0) == [])
        // desktop (nil percent) never stops
        var desktop = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = desktop.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(desktop.handle(.power(PowerStatus(percent: nil, onBattery: true)), now: t0) == [])
        // above the floor keeps running
        var above = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = above.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(above.handle(.power(PowerStatus(percent: 50, onBattery: true)), now: t0) == [])
    }

    @Test func floorStopClamshellDisarms() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: true, duration: nil), now: t0)
        let effects = policy.handle(.power(PowerStatus(percent: 10, onBattery: true)), now: t0)
        #expect(effects == [.disarmClamshell, .release(.batteryFloor), .notifyFloorStop(percent: 10)])
    }

    @Test func noAutoRestartAfterFloorStop() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: false, duration: 1800), now: t0)
        _ = policy.handle(.power(PowerStatus(percent: 15, onBattery: true)), now: t0)
        // AC re-attached, plenty of charge, and a tick past the old deadline: nothing restarts.
        #expect(policy.handle(.power(PowerStatus(percent: 80, onBattery: false)), now: t0) == [])
        #expect(policy.handle(.tick, now: t0.addingTimeInterval(9999)) == [])
        #expect(!policy.isActive)
    }

    @Test func powerWhileOffNoEffect() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        #expect(policy.handle(.power(PowerStatus(percent: 5, onBattery: true)), now: t0) == [])
    }

    // MARK: setDisplayAwake / setFloor

    @Test func setDisplayAwakeWhileActiveReacquires() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: true, duration: nil), now: t0)
        let effects = policy.handle(.setDisplayAwake(true), now: t0)
        // Re-acquires with display on; the clamshell system block is preserved.
        #expect(effects == [.acquire(AssertionSpec(displayAwake: true, systemSleepBlock: true))])
    }

    @Test func setDisplayAwakeWhileOffOnlyStores() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        #expect(policy.handle(.setDisplayAwake(true), now: t0) == [])
        let effects = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(effects == [.acquire(AssertionSpec(displayAwake: true, systemSleepBlock: false))])
    }

    @Test func setFloorStoresAndAppliesOnNextEvent() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(policy.handle(.setFloor(10), now: t0) == [])       // no immediate effect
        // 15% would have been fine at floor 20 but the new floor is 10:
        #expect(policy.handle(.power(PowerStatus(percent: 15, onBattery: true)), now: t0) == [])
        let effects = policy.handle(.power(PowerStatus(percent: 10, onBattery: true)), now: t0)
        #expect(effects == [.release(.batteryFloor), .notifyFloorStop(percent: 10)])
    }

    // MARK: clamshellArmFailed

    @Test func clamshellArmFailedTearsDownClamshellSession() {
        var policy = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = policy.handle(.start(clamshell: true, duration: nil), now: t0)
        let effects = policy.handle(.clamshellArmFailed, now: t0)
        #expect(effects == [.disarmClamshell, .release(.user)])
        #expect(!policy.isActive)
    }

    @Test func clamshellArmFailedIgnoredWhenNotClamshell() {
        var active = PowerPolicy(displayAwake: false, floorPercent: 20)
        _ = active.handle(.start(clamshell: false, duration: nil), now: t0)
        #expect(active.handle(.clamshellArmFailed, now: t0) == [])
        #expect(active.isActive, "a non-clamshell session is unaffected")

        var off = PowerPolicy(displayAwake: false, floorPercent: 20)
        #expect(off.handle(.clamshellArmFailed, now: t0) == [])
    }
}
