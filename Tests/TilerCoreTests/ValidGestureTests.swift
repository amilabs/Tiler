import Testing
@testable import TilerCore

// Positive controls: canonical swipes MUST fire exactly one correct action.
// These are the tests that make every "never fires" test below meaningful.
@Suite("Valid gestures") struct ValidGestureTests {

    @Test func leftSwipeFiresLeftHalf() {
        var sim = Sim()
        sim.performValidSwipe((dx: -0.15, dy: 0))
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false)])
    }

    @Test func rightSwipeFiresRightHalf() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0.15, dy: 0))
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false)])
    }

    @Test func upSwipeFiresMaximize() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0, dy: 0.15))
        #expect(sim.actions == [GestureAction(direction: .up, nextDisplay: false)])
    }

    @Test func cmdLeftSwipeTargetsNextDisplay() {
        var sim = Sim()
        sim.performValidSwipe((dx: -0.15, dy: 0), cmd: true)
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: true)])
    }

    @Test func cmdRightSwipeTargetsNextDisplay() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0.15, dy: 0), cmd: true)
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: true)])
    }

    @Test func cmdUpSwipeEmitsNothing() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0, dy: 0.15), cmd: true)
        #expect(sim.actions.isEmpty)
    }

    @Test func downSwipeEmitsNothing() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0, dy: -0.15))
        #expect(sim.actions.isEmpty)
    }

    // 20° off horizontal: |dx|/|dy| = 2.75 ≥ 2.0 — still a valid horizontal swipe.
    @Test func horizontalSwipeAt20DegreesFires() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 160, magnitude: 0.15))
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false)])
    }

    // 25° off vertical (65° from horizontal): |dy|/|dx| = 2.14 ≥ 1.6 — valid up swipe.
    @Test func upSwipeAt25DegreesOffVerticalFires() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 65, magnitude: 0.15))
        #expect(sim.actions == [GestureAction(direction: .up, nextDisplay: false)])
    }

    @Test func twoSequentialGesturesWithProperLiftOffBothFire() {
        var sim = Sim()
        sim.performValidSwipe((dx: -0.15, dy: 0))
        sim.performValidSwipe((dx: 0.15, dy: 0))
        #expect(sim.actions == [
            GestureAction(direction: .left, nextDisplay: false),
            GestureAction(direction: .right, nextDisplay: false),
        ])
    }

    // Fingers landing already in motion is normal usage — arming must not require
    // a stationary phase, only stable exact-3 presence.
    @Test func swipeWithoutStationaryArmPhaseFires() {
        var sim = Sim()
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.18, dy: 0), frames: 24)
        sim.liftAll()
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false)])
    }
}
