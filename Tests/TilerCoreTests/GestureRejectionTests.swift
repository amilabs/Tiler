import Testing
@testable import TilerCore

// Rejected-candidate diagnostics (fix-rebuild-gesture-loss): an ARMED 3-finger
// candidate that dies without confirming emits one `reject reason=…` line naming
// the failed gate — so a "gesture didn't fire" report is attributable from the
// log. Intent-filtered (≥ half the displacement threshold), rate-limited (1 s of
// frame time), zero lines for resting lifts, and never affects recognition.
@Suite("Gesture rejection diagnostic") struct GestureRejectionTests {

    private func rejects(_ lines: [String]) -> [String] {
        lines.filter { $0.hasPrefix("reject ") }
    }

    @Test func shortStrokeNamesShort() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: 0.06, dy: 0), frames: 10)   // below 0.10
        sim.liftAll()
        #expect(sim.actions.isEmpty)
        #expect(rejects(lines).count == 1)
        #expect(rejects(lines).first?.contains("reason=short") == true)
    }

    @Test func slowStrokeNamesSlow() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        // Far enough (0.15) but over 0.5 s → mean speed 0.3 < 0.5.
        sim.move(3, from: (0.5, 0.5), by: (dx: 0.15, dy: 0), frames: 60)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
        #expect(rejects(lines).count == 1)
        #expect(rejects(lines).first?.contains("reason=slow") == true)
    }

    @Test func liftedJustBeforeConfirmNamesBrief() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        // Fast and far, but the confirm streak (3 samples past threshold) can't
        // complete before lift-off: threshold crossed only on the last 2 frames.
        sim.move(3, from: (0.5, 0.5), by: (dx: 0.12, dy: 0), frames: 8)
        sim.liftAll()
        #expect(sim.actions.isEmpty)
        #expect(rejects(lines).count == 1)
        #expect(rejects(lines).first?.contains("reason=brief") == true)
    }

    @Test func diagonalNamesAmbiguous() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(3, at: 0.4, 0.4), frames: 5)
        sim.move(3, from: (0.4, 0.4), by: (dx: 0.11, dy: 0.11), frames: 12)  // 45°
        sim.liftAll()
        #expect(sim.actions.isEmpty)
        #expect(rejects(lines).count == 1)
        #expect(rejects(lines).first?.contains("reason=ambiguous") == true)
    }

    @Test func fingerDropNamesFingers() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: 0.06, dy: 0), frames: 6)
        sim.feed(fingers(2, at: 0.56, 0.5))   // one finger vanishes mid-stroke
        sim.liftAll()
        #expect(sim.actions.isEmpty)
        #expect(rejects(lines).count == 1)
        let line = rejects(lines).first ?? ""
        #expect(line.contains("reason=fingers"))
        #expect(line.contains("fingers=2"))
    }

    @Test func restingLiftStaysSilent() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 20)   // arms, no movement
        sim.liftAll()
        #expect(rejects(lines).isEmpty)
    }

    @Test func confirmedFireEmitsNoReject() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.performValidSwipe((dx: -0.15, dy: 0))
        #expect(sim.actions.count == 1)
        #expect(lines.count == 1)
        #expect(lines.first?.hasPrefix("fire ") == true)
        #expect(rejects(lines).isEmpty)
    }

    @Test func rejectionsAreRateLimitedByFrameTime() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        func shortStroke() {
            sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
            sim.move(3, from: (0.5, 0.5), by: (dx: 0.06, dy: 0), frames: 10)
            sim.liftAll(thenGap: 0.4)   // past cooldown, still < 1 s since the emit
        }
        shortStroke()
        shortStroke()                    // < 1 s after the first reject → suppressed
        #expect(rejects(lines).count == 1)
        sim.t += 1.2                     // let the rate-limit window pass
        shortStroke()
        #expect(rejects(lines).count == 2)
    }

    @Test func nilDiagnosticCostsNothingAndChangesNothing() {
        var sim = Sim()
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: 0.06, dy: 0), frames: 10)
        sim.liftAll()
        sim.performValidSwipe((dx: 0.15, dy: 0))
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false)])
    }
}
