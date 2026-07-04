import Testing
@testable import TilerCore

// Direction dominance per spec: horizontal |dx| ≥ 2.0·|dy| (≤26.6°),
// vertical-up |dy| ≥ 1.6·|dx| (≤32° off vertical, i.e. ≥58° from horizontal).
// Anything in between is ambiguous and must not act.
@Suite("Direction strictness") struct DirectionStrictnessTests {

    // 30° from horizontal — the explicitly-called-out ambiguous diagonal.
    @Test(arguments: [30.0, 150.0, 210.0, 330.0])
    func diagonal30DegreesNeverFires(angle: Double) {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: angle, magnitude: 0.15))
        #expect(sim.actions.isEmpty)
    }

    // 28° off horizontal: ratio 1.88 < 2.0 — just outside the horizontal cone.
    @Test func horizontalAt28DegreesRejected() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 28, magnitude: 0.15))
        #expect(sim.actions.isEmpty)
    }

    // 35° off vertical (55° from horizontal): ratio 1.43 < 1.6 — outside the up cone.
    @Test func upAt35DegreesOffVerticalRejected() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 55, magnitude: 0.15))
        #expect(sim.actions.isEmpty)
    }

    // The whole ambiguous band sampled every 3°: nothing may fire.
    @Test func ambiguousBandNeverFires() {
        for angle in stride(from: 28.0, through: 56.0, by: 3.0) {
            var sim = Sim()
            sim.performValidSwipe(vector(degrees: angle, magnitude: 0.15))
            #expect(sim.actions.isEmpty, "angle \(angle)° fired \(sim.actions)")
        }
    }

    // Down-ish diagonals are equally dead (down is not implemented at all).
    @Test func downDiagonalsNeverFire() {
        for angle in [250.0, 270.0, 290.0] {
            var sim = Sim()
            sim.performValidSwipe(vector(degrees: angle, magnitude: 0.15))
            #expect(sim.actions.isEmpty, "angle \(angle)° fired \(sim.actions)")
        }
    }
}
