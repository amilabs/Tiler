import Testing
@testable import TilerCore

// Deterministic seeded fuzz: whole classes of input that must never produce actions.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("Fuzz") struct FuzzTests {

    // Random streams whose active-contact count is never exactly 3:
    // no motion pattern whatsoever may fire.
    @Test func nonThreeFingerNoiseNeverFires() {
        var rng = SplitMix64(seed: 0x7113_2024)
        var sim = Sim()
        var burstsLeft = 800   // ≈ 10k+ frames
        while burstsLeft > 0 {
            burstsLeft -= 1
            let count = [0, 1, 2, 4, 5].randomElement(using: &rng)!
            let frames = Int.random(in: 1...30, using: &rng)
            let startX = Double.random(in: 0.2...0.8, using: &rng)
            let startY = Double.random(in: 0.2...0.8, using: &rng)
            let dx = Double.random(in: -0.3...0.3, using: &rng)
            let dy = Double.random(in: -0.3...0.3, using: &rng)
            let size = Double.random(in: 0.1...1.5, using: &rng)
            let cmd = Bool.random(using: &rng)
            if count == 0 {
                sim.feed([])
                sim.t += Double.random(in: 0...0.3, using: &rng)
            } else {
                sim.move(count, from: (startX, startY), by: (dx, dy),
                         frames: frames, cmd: cmd, size: size)
            }
        }
        #expect(sim.actions.isEmpty, "noise fired: \(sim.actions)")
    }

    // Perfect swipe kinematics at random angles inside the ambiguous band
    // (28°...56° from horizontal, mirrored to all quadrants): never fires.
    @Test func ambiguousAngleSwipesNeverFire() {
        var rng = SplitMix64(seed: 0xA0B1_C2D3)
        for _ in 0..<200 {
            let base = Double.random(in: 28...56, using: &rng)
            let quadrant = [base, 180 - base, 180 + base, 360 - base]
                .randomElement(using: &rng)!
            let magnitude = Double.random(in: 0.12...0.3, using: &rng)
            var sim = Sim()
            sim.performValidSwipe(vector(degrees: quadrant, magnitude: magnitude))
            #expect(sim.actions.isEmpty, "angle \(quadrant)° fired \(sim.actions)")
        }
    }

    // Sanity for the fuzz harness itself: the same harness CAN fire when the
    // input is a legitimate swipe (guards against a vacuously-passing fuzz).
    @Test func fuzzHarnessPositiveControl() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0.15, dy: 0))
        #expect(sim.actions.count == 1)
    }
}
