import Testing
@testable import TilerCore

// Gestures spec (shell-and-calibration delta): calibrated tunables apply to the
// live recognizer without restart, and never mid-gesture.
@Suite("Live tunables") struct LiveTunablesTests {

    @Test func updateAppliesFromCleanIdleOnly() {
        var strict = Tunables()
        strict.horizontalDominance = 2.0   // rejects 40°-tilted swipes

        var sim = Sim()                    // default 1.15: accepts 40°
        // Start a 40° gesture, swap tunables MID-gesture: old (loose) values must
        // finish the gesture — it still fires.
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.recognizer.updateTunables(strict)
        sim.move(3, from: (0.5, 0.5), by: vector(degrees: 40, magnitude: 0.15), frames: 18)
        sim.liftAll()
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false)],
                "mid-gesture swap must keep the old tunables")

        // After full lift-off + cooldown the pending strict tunables take effect.
        sim.performValidSwipe(vector(degrees: 40, magnitude: 0.15))
        #expect(sim.actions.count == 1, "strict tunables must reject the 40° swipe")
    }

    @Test func updateBeforeAnyTouchAppliesImmediately() {
        var strict = Tunables()
        strict.horizontalDominance = 2.0
        var sim = Sim()
        sim.recognizer.updateTunables(strict)
        sim.performValidSwipe(vector(degrees: 40, magnitude: 0.15))
        #expect(sim.actions.isEmpty)
    }
}
