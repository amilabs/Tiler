import Testing
@testable import TilerCore

// Direction dominance: horizontal |dx| ≥ 1.15·|dy| (≤41°; retuned twice from golden +
// rights traces — owner's natural rights tilt up to +40°), vertical-up |dy| ≥ 1.6·|dx|
// (≤32° off vertical, i.e. ≥58° from horizontal). The ~42°–58° band is ambiguous.
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

    // 40° off horizontal: ratio 1.19 ≥ 1.15 — inside the cone after the rights retune.
    @Test func horizontalAt40DegreesFires() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 40, magnitude: 0.15))
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false)])
    }

    // 44° off horizontal: ratio 1.04 < 1.15 — just outside the cone.
    @Test func horizontalAt44DegreesRejected() {
        var sim = Sim()
        sim.performValidSwipe(vector(degrees: 44, magnitude: 0.15))
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
        for angle in stride(from: 44.0, through: 56.0, by: 2.0) {
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
