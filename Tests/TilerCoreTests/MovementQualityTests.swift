import Testing
@testable import TilerCore

// Too short, too slow, jerky, reversed, or cancelled movements are ignored.
@Suite("Movement quality") struct MovementQualityTests {

    @Test func tooShortMovementNoAction() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.05, dy: 0), frames: 10) // < minDisplacement
        sim.hold(fingers(3, at: 0.45, 0.5), frames: 10)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // 0.12 displacement spread over ~480 ms → mean speed ≈ 0.25/s < 0.5/s.
    @Test func tooSlowMovementNoAction() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.12, dy: 0), frames: 58)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Exceeds maxGestureDuration before reaching the displacement threshold.
    @Test func timedOutGestureNoActionEvenIfItSpeedsUpLater() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.06, dy: 0), frames: 80)  // ~660 ms creep
        sim.move(3, from: (0.44, 0.5), by: (dx: -0.15, dy: 0), frames: 12) // fast finish
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Left, then back right, then left again: direction reversal aborts.
    @Test func reversedMovementNoAction() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.08, dy: 0), frames: 8)
        sim.move(3, from: (0.42, 0.5), by: (dx: 0.05, dy: 0), frames: 5)
        sim.move(3, from: (0.47, 0.5), by: (dx: -0.15, dy: 0), frames: 12)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // All fingers lift before the confirmation threshold — cancelled, no action.
    @Test func cancelledBeforeConfirmationNoAction() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.05, dy: 0), frames: 6)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Curving gesture: starts horizontal, bends vertical past the ambiguity bound.
    @Test func directionChangeMidGestureNoAction() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.07, dy: 0), frames: 7)
        sim.move(3, from: (0.43, 0.5), by: (dx: 0, dy: 0.14), frames: 14)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }
}
