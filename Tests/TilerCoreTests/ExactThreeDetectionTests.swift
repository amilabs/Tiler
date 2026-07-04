import Testing
@testable import TilerCore

// The core reliability requirement: only exactly-3 stable active contacts may gesture.
// Every scenario here is a blocker from specs/gestures/spec.md.
@Suite("Exact-three detection") struct ExactThreeDetectionTests {

    @Test(arguments: [
        (dx: 0.0, dy: -0.20), (dx: 0.0, dy: 0.20),   // vertical scroll
        (dx: -0.20, dy: 0.0), (dx: 0.20, dy: 0.0),   // horizontal scroll
        (dx: -0.14, dy: 0.14), (dx: 0.14, dy: -0.14) // diagonal scroll
    ]) func twoFingerScrollNeverFires(delta: (dx: Double, dy: Double)) {
        var sim = Sim()
        sim.hold(fingers(2, at: 0.5, 0.5), frames: 5)
        sim.move(2, from: (0.5, 0.5), by: delta, frames: 24)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    @Test func oneFingerMoveNeverFires() {
        var sim = Sim()
        sim.move(1, from: (0.3, 0.5), by: (dx: 0.3, dy: 0), frames: 24)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    @Test func fourFingerSwipeNeverFires() {
        var sim = Sim()
        sim.hold(fingers(4, at: 0.5, 0.5), frames: 5)
        sim.move(4, from: (0.5, 0.5), by: (dx: -0.2, dy: 0), frames: 24)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Stale artifact: third contact stuck at size 0 while two fingers make a
    // perfectly swipe-shaped movement. The artifact must not make it "three".
    @Test func staleSizeZeroThirdContactNotCounted() {
        var sim = Sim()
        let stale = Contact(deviceID: 1, fingerID: 77, state: .touching, size: 0, x: 0.7, y: 0.7)
        sim.hold(fingers(2, at: 0.5, 0.5) + [stale], frames: 5)
        sim.move(2, from: (0.5, 0.5), by: (dx: -0.2, dy: 0), frames: 24, extra: [stale])
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Ended-state contact with a plausible size must not count either.
    @Test(arguments: [ContactState.breaking, .lingering, .leaving, .notTracking, .hovering])
    func endedOrHoveringThirdContactNotCounted(state: ContactState) {
        var sim = Sim()
        let ghost = Contact(deviceID: 1, fingerID: 77, state: state, size: 0.5, x: 0.7, y: 0.7)
        sim.hold(fingers(2, at: 0.5, 0.5) + [ghost], frames: 5)
        sim.move(2, from: (0.5, 0.5), by: (dx: -0.2, dy: 0), frames: 24, extra: [ghost])
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    @Test func palmAlongsideTwoFingersNeverFires() {
        var sim = Sim()
        sim.hold(fingers(2, at: 0.5, 0.5) + [palm()], frames: 5)
        sim.move(2, from: (0.5, 0.5), by: (dx: -0.2, dy: 0), frames: 24, extra: [palm()])
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Spec: a resting palm blocks arming even with exactly 3 valid fingers.
    @Test func palmAlongsideThreeFingersBlocksArming() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5) + [palm()], frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18, extra: [palm()])
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // 2→3→2: a third finger brushes the pad for 2 frames mid-scroll.
    @Test func briefThirdFingerDuringScrollNeverFires() {
        var sim = Sim()
        sim.hold(fingers(2, at: 0.5, 0.5), frames: 4)
        sim.move(2, from: (0.5, 0.5), by: (dx: 0, dy: -0.05), frames: 6)
        sim.hold(fingers(3, at: 0.5, 0.45), frames: 2)          // brief 3rd touch
        sim.move(2, from: (0.5, 0.45), by: (dx: 0, dy: -0.15), frames: 18)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // 3→2 before confirmation: gesture aborts, remaining movement must not fire.
    @Test func fingerLiftBeforeConfirmationAborts() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.04, dy: 0), frames: 5) // below confirm
        sim.move(2, from: (0.46, 0.5), by: (dx: -0.20, dy: 0), frames: 20)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // 3→4 before confirmation: aborts, and 4th lifting back to 3 must not re-arm
    // (no full lift-off happened).
    @Test func fourthFingerAbortsAndThreeAfterwardsStaysLocked() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.04, dy: 0), frames: 5)
        sim.hold(fingers(4, at: 0.46, 0.5), frames: 3)
        sim.hold(fingers(3, at: 0.46, 0.5), frames: 4)
        sim.move(3, from: (0.46, 0.5), by: (dx: -0.18, dy: 0), frames: 20)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // 3→2→3 without ever reaching zero contacts: never re-arms. Then a clean
    // gesture after real lift-off fires (positive control in the same test).
    @Test func reformingThreeWithoutLiftOffDoesNotRearm() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.hold(fingers(2, at: 0.5, 0.5), frames: 3)
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.18, dy: 0), frames: 20)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
        sim.performValidSwipe((dx: -0.15, dy: 0))
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false)])
    }

    // The classic blocker: an ongoing 2-finger scroll gains a third finger and the
    // trio keeps moving with perfect swipe kinematics. Session is poisoned — no action.
    @Test func thirdFingerAddedDuringScrollThenSwipeMotionNeverFires() {
        var sim = Sim()
        sim.hold(fingers(2, at: 0.5, 0.6), frames: 4)
        sim.move(2, from: (0.5, 0.6), by: (dx: 0, dy: -0.10), frames: 20) // ~200 ms scroll
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: 0, dy: 0.15), frames: 18)  // "maximize" shape
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Two fingers rest, a third joins much later (no scroll motion at all): still dirty.
    @Test func lateThirdFingerAssemblyNeverFires() {
        var sim = Sim()
        sim.hold(fingers(2, at: 0.5, 0.5), frames: 18)                    // ~150 ms
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Positive control for the session rule: naturally staggered touchdown
    // (1 → 2 → 3 within ~35 ms) is normal usage and must fire.
    @Test func staggeredTouchdownWithinAssemblyWindowFires() {
        var sim = Sim()
        sim.hold(fingers(1, at: 0.5, 0.5), frames: 2)
        sim.hold(fingers(2, at: 0.5, 0.5), frames: 2)
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18)
        sim.liftAll()
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false)])
    }

    // Four fingers held, one lifts, remaining three swipe: 4→3 without lift-off.
    @Test func fourThenThreeWithoutLiftOffNeverFires() {
        var sim = Sim()
        sim.hold(fingers(4, at: 0.5, 0.5), frames: 6)
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }

    // Mutation guard: with the assembly window disabled (huge), the scroll+third-finger
    // scenario WOULD fire — proving the window rule is the active blocker above, and
    // that these session tests actually bite.
    @Test func assemblyWindowIsTheActiveBlockerForLateThirdFinger() {
        var loose = Tunables()
        loose.touchdownAssemblyWindow = 10.0
        var sim = Sim(tunables: loose)
        sim.hold(fingers(2, at: 0.5, 0.6), frames: 4)
        sim.hold(fingers(3, at: 0.5, 0.6), frames: 5)   // late third, no count decrease
        sim.move(3, from: (0.5, 0.6), by: (dx: -0.15, dy: 0), frames: 18)
        sim.liftAll()
        #expect(sim.actions.count == 1, "loosened window must fire — session tests would be vacuous")
    }

    // Momentum-style: scroll, lift, then 3 fingers land but stay still.
    @Test func threeFingersLandingStillAfterScrollNeverFires() {
        var sim = Sim()
        sim.move(2, from: (0.5, 0.6), by: (dx: 0, dy: -0.2), frames: 20)
        sim.liftAll(thenGap: 0.4)
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 30)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
    }
}
