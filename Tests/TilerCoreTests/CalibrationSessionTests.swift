import Foundation
import Testing
@testable import TilerCore

// Calibration engine (calibration spec): prompt progression, per-attempt verdicts,
// live accuracy, safely-clamped tunable suggestions, diagnostic recording.
@Suite("Calibration session") struct CalibrationSessionTests {

    /// Drives a session like Sim drives the recognizer: 120 Hz frames.
    struct Driver {
        let session: CalibrationSession
        var t = 10.0
        let dt = 1.0 / 120.0
        var events: [CalibrationSession.Event] = []

        init(_ session: CalibrationSession) {
            self.session = session
        }

        mutating func feed(_ contacts: [Contact]) {
            events.append(contentsOf: session.process(TouchFrame(timestamp: t, contacts: contacts)))
            t += dt
        }

        /// Arm, swipe by `delta`, lift, wait out cooldown.
        mutating func attempt(_ delta: (dx: Double, dy: Double)) {
            for _ in 0..<5 { feed(fingers(3, at: 0.5, 0.5)) }
            for i in 1...18 {
                let f = Double(i) / 18.0
                feed(fingers(3, at: 0.5 + delta.dx * f, 0.5 + delta.dy * f))
            }
            feed([])
            t += 0.5
        }

        mutating func twoFingerScroll() {
            for i in 1...20 {
                feed(fingers(2, at: 0.5, 0.5 - 0.01 * Double(i)))
            }
            feed([])
            t += 0.5
        }
    }

    @Test func startsWithTheFirstPrompt() {
        let session = CalibrationSession(gestures: [.left, .right], attemptsPerGesture: 3)
        #expect(session.currentStep == .init(gesture: .left, attemptsRequired: 3))
    }

    @Test func recognizedAttemptsAdvanceThroughSteps() {
        let session = CalibrationSession(gestures: [.left, .right], attemptsPerGesture: 2)
        var driver = Driver(session)
        driver.attempt((dx: -0.15, dy: 0))
        driver.attempt((dx: -0.15, dy: 0))
        #expect(driver.events.contains(.attemptRecognized(step: .left, attempt: 1)))
        #expect(driver.events.contains(.attemptRecognized(step: .left, attempt: 2)))
        #expect(driver.events.contains(.stepCompleted(.left, accuracy: 1.0)))
        #expect(session.currentStep?.gesture == .right)
    }

    @Test func missedAttemptReportsMeasuredAngle() {
        let session = CalibrationSession(gestures: [.left], attemptsPerGesture: 2)
        var driver = Driver(session)
        // 140° = left tilted 40° up: outside the 37.6° horizontal cone → not recognized.
        driver.attempt(vector(degrees: 140, magnitude: 0.15))
        let missed = driver.events.compactMap { event -> Double?? in
            if case .attemptMissed(step: .left, attempt: 1, let angle) = event { return angle }
            return nil
        }
        #expect(missed.count == 1)
        let angle = missed[0] ?? nil
        #expect(angle != nil && abs(angle! - 140) < 4, "angle \(String(describing: angle))")
    }

    @Test func nonThreeFingerNoiseConsumesNoAttempts() {
        let session = CalibrationSession(gestures: [.left], attemptsPerGesture: 1)
        var driver = Driver(session)
        driver.twoFingerScroll()
        #expect(driver.events.isEmpty)
        driver.attempt((dx: -0.15, dy: 0))
        #expect(driver.events.contains(.attemptRecognized(step: .left, attempt: 1)))
    }

    @Test func tiltedAttemptsRelaxHorizontalDominanceWithFloorClamp() {
        let session = CalibrationSession(gestures: [.right], attemptsPerGesture: 3)
        var driver = Driver(session)
        // 40° tilt: required dominance ≈ 1.19; suggestion 1.19·0.95 ≈ 1.13 → floor 1.15.
        for _ in 0..<3 { driver.attempt(vector(degrees: 40, magnitude: 0.15)) }
        guard case .sessionCompleted(let result)? = driver.events.last else {
            Issue.record("no sessionCompleted, events: \(driver.events)")
            return
        }
        #expect(result.suggested.horizontalDominance == CalibrationSession.horizontalDominanceRange.lowerBound)
    }

    @Test func cleanAttemptsKeepDefaultDominance() {
        let session = CalibrationSession(gestures: [.right], attemptsPerGesture: 3)
        var driver = Driver(session)
        for _ in 0..<3 { driver.attempt(vector(degrees: 20, magnitude: 0.15)) }
        guard case .sessionCompleted(let result)? = driver.events.last else {
            Issue.record("no sessionCompleted")
            return
        }
        #expect(result.suggested.horizontalDominance == Tunables.default.horizontalDominance)
    }

    @Test func accuracyReflectsMisses() {
        let session = CalibrationSession(gestures: [.right], attemptsPerGesture: 4)
        var driver = Driver(session)
        driver.attempt(vector(degrees: 20, magnitude: 0.15))   // recognized
        driver.attempt(vector(degrees: 44, magnitude: 0.15))   // ambiguous → missed
        driver.attempt(vector(degrees: 20, magnitude: 0.15))   // recognized
        driver.attempt(vector(degrees: 44, magnitude: 0.15))   // missed
        #expect(driver.events.contains(.stepCompleted(.right, accuracy: 0.5)))
        guard case .sessionCompleted(let result)? = driver.events.last else {
            Issue.record("no sessionCompleted")
            return
        }
        #expect(result.stepAccuracies[.right] == 0.5)
    }

    @Test func recordsAllFramesForDiagnostics() {
        let session = CalibrationSession(gestures: [.left], attemptsPerGesture: 1)
        var driver = Driver(session)
        driver.attempt((dx: -0.15, dy: 0))
        #expect(session.recordedFrames.count == 24) // 5 arm + 18 move + 1 lift
    }
}
