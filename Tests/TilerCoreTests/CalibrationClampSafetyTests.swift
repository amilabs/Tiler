import Foundation
import Testing
@testable import TilerCore

// Calibration spec invariant: NO value inside the clamp ranges may re-enable
// false-positive blocker classes. Tested at all range corners.
@Suite("Calibration clamp safety") struct CalibrationClampSafetyTests {

    static let corners: [Tunables] = {
        var list: [Tunables] = []
        for h in [CalibrationSession.horizontalDominanceRange.lowerBound,
                  CalibrationSession.horizontalDominanceRange.upperBound] {
            for v in [CalibrationSession.verticalDominanceRange.lowerBound,
                      CalibrationSession.verticalDominanceRange.upperBound] {
                var t = Tunables()
                t.horizontalDominance = h
                t.verticalDominance = v
                list.append(t)
            }
        }
        return list
    }()

    // The owner's golden recording: its first 190 s are pure blocker material
    // (2-finger scrolls incl. momentum, third-finger additions, 2→3→2, palm) —
    // segment analysis 2026-07-04; first legitimate swipe fires at t≈200 s.
    @Test(arguments: corners)
    func goldenBlockerWindowStaysSilentAtCorners(tunables: Tunables) throws {
        let url = Bundle.module.url(forResource: "golden-20260704-194040",
                                    withExtension: "jsonl", subdirectory: "Fixtures")
        guard let url else {
            Issue.record("golden fixture missing")
            return
        }
        let frames = try TraceIO.read(from: url)
        guard let t0 = frames.first?.timestamp else { return }
        let recognizer = GestureRecognizer(tunables: tunables)
        let actions = frames
            .filter { $0.timestamp - t0 <= 190 }
            .compactMap { recognizer.process($0) }
        #expect(actions.isEmpty, "corner \(tunables.horizontalDominance)/\(tunables.verticalDominance) fired \(actions) in the blocker window")
    }

    @Test(arguments: corners)
    func syntheticBlockersNeverFireAtCorners(tunables: Tunables) {
        // Third finger added mid-scroll, then swipe-shaped motion.
        var sim = Sim(tunables: tunables)
        sim.hold(fingers(2, at: 0.5, 0.6), frames: 4)
        sim.move(2, from: (0.5, 0.6), by: (dx: 0, dy: -0.10), frames: 20)
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18)
        sim.liftAll()
        #expect(sim.actions.isEmpty)

        // Palm resting alongside three fingers.
        var palmSim = Sim(tunables: tunables)
        palmSim.hold(fingers(3, at: 0.5, 0.5) + [palm()], frames: 5)
        palmSim.move(3, from: (0.5, 0.5), by: (dx: -0.15, dy: 0), frames: 18, extra: [palm()])
        palmSim.liftAll()
        #expect(palmSim.actions.isEmpty)

        // 2→3→2 brush during a scroll.
        var brushSim = Sim(tunables: tunables)
        brushSim.hold(fingers(2, at: 0.5, 0.5), frames: 4)
        brushSim.move(2, from: (0.5, 0.5), by: (dx: 0, dy: -0.05), frames: 6)
        brushSim.hold(fingers(3, at: 0.5, 0.45), frames: 2)
        brushSim.move(2, from: (0.5, 0.45), by: (dx: 0, dy: -0.15), frames: 18)
        brushSim.liftAll()
        #expect(brushSim.actions.isEmpty)
    }

    // Positive control: the clamps must never break legitimate swipes either.
    @Test(arguments: corners)
    func canonicalSwipesStillFireAtCorners(tunables: Tunables) {
        var sim = Sim(tunables: tunables)
        sim.performValidSwipe((dx: -0.15, dy: 0))
        sim.performValidSwipe((dx: 0.15, dy: 0))
        sim.performValidSwipe((dx: 0, dy: 0.15))
        #expect(sim.actions == [
            GestureAction(direction: .left, nextDisplay: false),
            GestureAction(direction: .right, nextDisplay: false),
            GestureAction(direction: .up, nextDisplay: false),
        ])
    }
}
