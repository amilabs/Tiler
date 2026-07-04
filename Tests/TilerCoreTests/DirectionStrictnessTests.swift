import Testing
@testable import TilerCore

// Direction dominance: horizontal |dx| ≥ 1.3·|dy| (≤37.6°; retuned 2026-07-04 from
// golden-trace data — owner's natural rights tilt to +36°, their diagonals start ≥48°),
// vertical-up |dy| ≥ 1.6·|dx| (≤32° off vertical, i.e. ≥58° from horizontal).
// Anything in the 37.6°–58° band is ambiguous and must not act.
@Suite("Direction strictness") struct DirectionStrictnessTests {

    // 45° — dead center of the ambiguous band, in all four quadrants.
    @Test(arguments: [45.0, 135.0, 225.0, 315.0])
    func diagonal45DegreesNeverFires(angle: Double) {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: angle, magnitude: 0.15))
        #expect(sim.actions.isEmpty)
    }

    // 35° off horizontal: ratio 1.43 ≥ 1.3 — inside the (relaxed) horizontal cone.
    @Test func horizontalAt35DegreesFires() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 35, magnitude: 0.15))
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false)])
    }

    // 40° off horizontal: ratio 1.19 < 1.3 — just outside the horizontal cone.
    @Test func horizontalAt40DegreesRejected() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 40, magnitude: 0.15))
        #expect(sim.actions.isEmpty)
    }

    // 35° off vertical (55° from horizontal): ratio 1.43 < 1.6 — outside the up cone.
    @Test func upAt35DegreesOffVerticalRejected() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 55, magnitude: 0.15))
        #expect(sim.actions.isEmpty)
    }

    // The whole ambiguous band sampled every 2°: nothing may fire.
    @Test func ambiguousBandNeverFires() {
        for angle in stride(from: 40.0, through: 56.0, by: 2.0) {
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
