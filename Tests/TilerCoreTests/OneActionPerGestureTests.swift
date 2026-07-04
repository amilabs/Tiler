import Testing
@testable import TilerCore

// One physical gesture = at most one action, enforced by lockout + lift-off + cooldown.
@Suite("One action per gesture") struct OneActionPerGestureTests {

    @Test func continuedMovementAfterFireProducesNoSecondAction() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.7, 0.5), frames: 5)
        sim.move(3, from: (0.7, 0.5), by: (dx: -0.4, dy: 0), frames: 60) // long swipe
        sim.liftAll()
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false)])
    }

    @Test func callbackStormAfterFireIsIgnored() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18)
        sim.hold(fingers(3, at: 0.35, 0.5), frames: 100)  // stationary storm post-fire
        sim.liftAll()
        #expect(sim.actions.count == 1)
    }

    // Re-landing 10 ms after lift-off violates full-lift-off + cooldown: no re-arm.
    @Test func immediateRelandAfterFireCannotRearm() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18)
        sim.feed([])                       // lift
        sim.t += 0.010                     // only 10 ms of silence
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: 0.15, dy: 0), frames: 18)
        sim.liftAll()
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false)])
    }

    // After a proper quiet + cooldown period the recognizer re-arms (positive control).
    @Test func rearmAfterQuietAndCooldownFires() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18)
        sim.feed([])
        sim.t += 0.400                     // > liftOffQuiet + cooldown
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: 0.15, dy: 0), frames: 18)
        sim.liftAll()
        #expect(sim.actions == [
            GestureAction(direction: .left, nextDisplay: false),
            GestureAction(direction: .right, nextDisplay: false),
        ])
    }

    // An aborted gesture also requires full lift-off before anything new.
    @Test func abortAlsoRequiresLiftOffBeforeNextGesture() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.hold(fingers(4, at: 0.5, 0.5), frames: 2)   // abort via 3→4
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)   // back to 3, no lift-off
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.18, dy: 0), frames: 20)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }
}
