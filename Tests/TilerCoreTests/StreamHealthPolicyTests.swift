import Foundation
import Testing
@testable import TilerCore

// Touch-stream recovery decisions (app-shell "Gesture stream recovery" spec).
// Pure: the guardian feeds in ages/signatures, gets back rebuild verdicts.
@Suite("Stream health policy") struct StreamHealthPolicyTests {

    // MARK: device drift (signature = sorted device IDs, or [count] in fallback mode)

    @Test func identicalSignaturesAreNotDrift() {
        #expect(!StreamHealthPolicy.deviceDrift(attached: [7, 42], current: [7, 42]))
    }

    @Test func orderDoesNotMatter() {
        #expect(!StreamHealthPolicy.deviceDrift(attached: [42, 7], current: [7, 42]))
    }

    @Test func changedIDsAreDrift() {
        #expect(StreamHealthPolicy.deviceDrift(attached: [7], current: [9]))
    }

    @Test func addedDeviceIsDrift() {
        #expect(StreamHealthPolicy.deviceDrift(attached: [7], current: [7, 9]))
    }

    @Test func removedDeviceIsDrift() {
        #expect(StreamHealthPolicy.deviceDrift(attached: [7, 9], current: [7]))
    }

    @Test func devicesAppearingAfterEmptyStartIsDrift() {
        // start() failed to find devices, they showed up later → rebuild to attach.
        #expect(StreamHealthPolicy.deviceDrift(attached: [], current: [7]))
    }

    @Test func noEnumerationInfoIsNotDrift() {
        // A failed fresh enumeration says nothing — never treat it as drift.
        #expect(!StreamHealthPolicy.deviceDrift(attached: [7], current: nil))
        #expect(!StreamHealthPolicy.deviceDrift(attached: [], current: nil))
    }

    @Test func bothEmptyIsNotDrift() {
        #expect(!StreamHealthPolicy.deviceDrift(attached: [], current: []))
    }

    // MARK: silence self-heal
    // Fires only when ALL hold: unlocked, silent ≥ 600 s, HID ≤ 60 s old,
    // last rebuild ≥ 600 s ago.

    @Test func silentStreamWithFreshHIDHeals() {
        #expect(StreamHealthPolicy.shouldSelfHeal(
            silentFor: 601, hidAgo: 5, sinceLastRebuild: 3600, screenLocked: false))
    }

    @Test func exactThresholdsHeal() {
        #expect(StreamHealthPolicy.shouldSelfHeal(
            silentFor: 600, hidAgo: 60, sinceLastRebuild: 600, screenLocked: false))
    }

    @Test func recentFramesBlockHealing() {
        #expect(!StreamHealthPolicy.shouldSelfHeal(
            silentFor: 599, hidAgo: 5, sinceLastRebuild: 3600, screenLocked: false))
    }

    @Test func staleHIDBlocksHealing() {
        // Nobody at the machine — silence is expected, not evidence of death.
        #expect(!StreamHealthPolicy.shouldSelfHeal(
            silentFor: 7200, hidAgo: 61, sinceLastRebuild: 3600, screenLocked: false))
    }

    @Test func missingHIDInfoBlocksHealing() {
        #expect(!StreamHealthPolicy.shouldSelfHeal(
            silentFor: 7200, hidAgo: nil, sinceLastRebuild: 3600, screenLocked: false))
    }

    @Test func lockedScreenBlocksHealing() {
        #expect(!StreamHealthPolicy.shouldSelfHeal(
            silentFor: 7200, hidAgo: 5, sinceLastRebuild: 3600, screenLocked: true))
    }

    @Test func cooldownBlocksRepeatHealing() {
        // External-mouse user: silent trackpad + live cursor forever — cap the churn.
        #expect(!StreamHealthPolicy.shouldSelfHeal(
            silentFor: 7200, hidAgo: 5, sinceLastRebuild: 599, screenLocked: false))
    }

    // MARK: display-change rebuild politeness (fix-rebuild-gesture-loss)
    // Rebuild only when it might be needed and cannot hurt: skip when a rebuild
    // just happened (notification bursts) or frames arrived after the change
    // (stream demonstrably alive — a rebuild would only risk eating a stroke).

    @Test func idleStaleStreamRebuildsOnDisplayChange() {
        #expect(StreamHealthPolicy.displayChangeRebuild(silentFor: 300, sinceLastRebuild: 3600))
    }

    @Test func recentFramesSkipTheRebuild() {
        // 2026-07-31 incident: charger unplug fired display changes while the
        // stream was alive — the rebuilds ate the owner's swipes.
        #expect(!StreamHealthPolicy.displayChangeRebuild(silentFor: 0.4, sinceLastRebuild: 3600))
    }

    @Test func recentRebuildCoalescesTheBurst() {
        // Two notifications 6 s apart must produce at most one rebuild.
        #expect(!StreamHealthPolicy.displayChangeRebuild(silentFor: 300, sinceLastRebuild: 6))
    }

    @Test func displayChangeBoundaries() {
        // At exactly the alive window the stream no longer counts as alive.
        #expect(StreamHealthPolicy.displayChangeRebuild(silentFor: 1.0, sinceLastRebuild: 3600))
        #expect(!StreamHealthPolicy.displayChangeRebuild(silentFor: 0.99, sinceLastRebuild: 3600))
        // At exactly the coalesce horizon a new rebuild is allowed again.
        #expect(StreamHealthPolicy.displayChangeRebuild(silentFor: 300, sinceLastRebuild: 10))
        #expect(!StreamHealthPolicy.displayChangeRebuild(silentFor: 300, sinceLastRebuild: 9.9))
    }
}
