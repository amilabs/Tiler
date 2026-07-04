import Testing
@testable import TilerCore

// Gestures spec (shell-and-calibration delta): calibrated tunables apply to the
// live recognizer without restart, and never mid-gesture.
@Suite("Live tunables") struct LiveTunablesTests {

    @Test func updateAppliesFromCleanIdleOnly() {
        var loose = Tunables()
        loose.horizontalDominance = 1.15   // accepts 40°-tilted swipes

        var sim = Sim()                    // default 1.3: rejects 40°
        // Start a 40° gesture, swap tunables MID-gesture: must still be rejected.
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.recognizer.updateTunables(loose)
        sim.move(3, from: (0.5, 0.5), by: vector(degrees: 40, magnitude: 0.15), frames: 18)
        sim.liftAll()
        #expect(sim.actions.isEmpty, "mid-gesture swap must keep the old tunables")

        // After full lift-off + cooldown the pending tunables take effect.
        sim.performValidSwipe(vector(degrees: 40, magnitude: 0.15))
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false)])
    }

    @Test func updateBeforeAnyTouchAppliesImmediately() {
        var loose = Tunables()
        loose.horizontalDominance = 1.15
        var sim = Sim()
        sim.recognizer.updateTunables(loose)
        sim.performValidSwipe(vector(degrees: 40, magnitude: 0.15))
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false)])
    }
}
