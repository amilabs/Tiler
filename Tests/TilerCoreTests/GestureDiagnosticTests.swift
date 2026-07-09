import Testing
@testable import TilerCore

// The opt-in diagnostic side-channel (for catching false positives with evidence).
// It must fire exactly once per confirmed decision, carry the movement/modifier
// evidence, and never affect the recognition result.
@Suite("Gesture diagnostic") struct GestureDiagnosticTests {

    @Test func fireEmitsOneLineWithEvidence() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.performValidSwipe((dx: -0.15, dy: 0))

        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false)])
        #expect(lines.count == 1)
        let line = lines.first ?? ""
        #expect(line.contains("fire dir=left"))
        #expect(line.contains("action=left"))
        #expect(line.contains("fingers=3"))
        #expect(line.contains("cmd=false"))
        #expect(line.contains("shift=false"))
    }

    @Test func modifiersAndThirdAreReported() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.performValidSwipe((dx: 0, dy: 0.15), shift: true)   // ⇧up → center-third
        #expect(lines.first?.contains("action=up-third") == true)
        #expect(lines.first?.contains("shift=true") == true)
    }

    @Test func unsetDiagnosticIsHarmless() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0.15, dy: 0))
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false)])
    }
}
