import Testing
@testable import TilerCore

// No-arm session diagnostics (add-noarm-diagnostics): attempts whose third finger
// flickers or hovers never arm and used to log nothing — the dark matter behind
// "почти не ловит" reports. A session that saw exactly-3 active at least once but
// never armed emits one `noarm` line; reject lines carry `near=` so a hovering
// finger is distinguishable from a fully lifted one.
@Suite("No-arm diagnostic") struct NoArmDiagnosticTests {

    private func noarms(_ lines: [String]) -> [String] {
        lines.filter { $0.hasPrefix("noarm ") }
    }

    @Test func flickeringThirdFingerEmitsNoArm() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        // Exact-3 never stays stable for stableArmFrames(4): 2 frames of 3, then a
        // frame of 2, repeatedly — the arming streak keeps resetting.
        for _ in 0..<4 {
            sim.hold(fingers(3, at: 0.5, 0.5), frames: 2)
            sim.hold(fingers(2, at: 0.5, 0.5), frames: 1)
        }
        sim.liftAll()
        #expect(sim.actions.isEmpty)
        #expect(noarms(lines).count == 1)
        let line = noarms(lines).first ?? ""
        #expect(line.contains("frames3=8"))
        #expect(line.contains("maxStreak=2"))
    }

    @Test func cleanFireEmitsNoNoArm() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.performValidSwipe((dx: -0.15, dy: 0))
        sim.liftAll(thenGap: 1.5)
        #expect(sim.actions.count == 1)
        #expect(noarms(lines).isEmpty)
    }

    @Test func pureTwoFingerScrollStaysSilent() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(2, at: 0.5, 0.5), frames: 5)
        sim.move(2, from: (0.5, 0.5), by: (dx: 0, dy: -0.3), frames: 20)
        sim.liftAll()
        #expect(lines.isEmpty)   // never saw 3 — no noarm, no reject
    }

    @Test func hoveringFingerIsCountedInRejects() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: 0, dy: 0.06), frames: 6)
        // The third finger stops PRESSING but still hovers over the pad.
        let hoverThird = fingers(2, at: 0.5, 0.56, idBase: 1)
            + fingers(1, at: 0.56, 0.56, state: .hovering, idBase: 3)
        sim.feed(hoverThird)
        sim.liftAll()
        let line = lines.filter { $0.hasPrefix("reject ") }.first ?? ""
        #expect(line.contains("reason=fingers"))
        #expect(line.contains("raw=2"))
        #expect(line.contains("near=1"))   // hovering — 1 mm off, not gone
    }

    @Test func fullyLiftedFingerShowsNearZero() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        sim.hold(fingers(3, at: 0.5, 0.5), frames: 5)
        sim.move(3, from: (0.5, 0.5), by: (dx: 0.06, dy: 0), frames: 6)
        sim.feed(fingers(2, at: 0.56, 0.5))
        sim.liftAll()
        let line = lines.filter { $0.hasPrefix("reject ") }.first ?? ""
        #expect(line.contains("raw=2"))
        #expect(line.contains("near=0"))
    }

    @Test func noArmRateLimited() {
        var sim = Sim()
        var lines: [String] = []
        sim.recognizer.diagnostic = { lines.append($0) }
        func flickerSession() {
            for _ in 0..<3 {
                sim.hold(fingers(3, at: 0.5, 0.5), frames: 2)
                sim.hold(fingers(2, at: 0.5, 0.5), frames: 1)
            }
            sim.liftAll(thenGap: 0.4)
        }
        flickerSession()
        flickerSession()                 // < 1 s later → suppressed
        #expect(noarms(lines).count == 1)
        sim.t += 1.2
        flickerSession()
        #expect(noarms(lines).count == 2)
    }
}
