import Foundation

/// Guided per-gesture calibration engine (calibration spec). Pure logic:
/// feed the same TouchFrames the recognizer sees; get prompt progression,
/// per-attempt verdicts with live accuracy, and safely-clamped suggested tunables.
public final class CalibrationSession {
    public struct Step: Equatable, Sendable {
        public let gesture: GestureDirection
        public let attemptsRequired: Int

        public init(gesture: GestureDirection, attemptsRequired: Int) {
            self.gesture = gesture
            self.attemptsRequired = attemptsRequired
        }
    }

    public enum Event: Equatable, Sendable {
        case attemptRecognized(step: GestureDirection, attempt: Int)
        case attemptMissed(step: GestureDirection, attempt: Int, measuredAngle: Double?)
        case stepCompleted(GestureDirection, accuracy: Double)
        case sessionCompleted(CalibrationResult)
    }

    /// Safe ranges for calibrated values (calibration spec): chosen so no in-range
    /// value can re-enable false-positive blocker classes. Proven by property tests.
    public static let horizontalDominanceRange: ClosedRange<Double> = 1.15...2.0
    public static let verticalDominanceRange: ClosedRange<Double> = 1.35...2.2
    /// Extra margin below the most-demanding attempt so borderline repeats still land.
    private static let dominanceMargin = 0.95

    public private(set) var currentStep: Step?
    public private(set) var recordedFrames: [TouchFrame] = []

    private let steps: [Step]
    private let baseTunables: Tunables
    private var stepIndex = 0
    private var attemptNumber = 0
    private var recognizedInStep = 0

    private let recognizer: GestureRecognizer

    // Per-attempt accumulation.
    private var attemptActive = false
    private var attemptMaxSimultaneous = 0
    private var attemptRecognizedDirection: GestureDirection?
    private var episode: [(x: Double, y: Double)] = []
    private var bestEpisodeVector: (dx: Double, dy: Double)?

    // Collected evidence across the whole session.
    private var requiredHorizontalDominance: [Double] = []
    private var requiredVerticalDominance: [Double] = []
    private var accuracies: [GestureDirection: Double] = [:]

    public init(gestures: [GestureDirection] = [.left, .right, .up],
                attemptsPerGesture: Int = 5,
                tunables: Tunables = .default) {
        steps = gestures.map { Step(gesture: $0, attemptsRequired: attemptsPerGesture) }
        baseTunables = tunables
        recognizer = GestureRecognizer(tunables: tunables)
        currentStep = steps.first
    }

    /// Feed one frame; returns the events it triggered (usually none, up to three
    /// on an attempt-ending lift-off).
    public func process(_ frame: TouchFrame) -> [Event] {
        guard currentStep != nil else { return [] }
        recordedFrames.append(frame)

        if let action = recognizer.process(frame) {
            attemptRecognizedDirection = action.direction
        }

        let active = frame.contacts.filter { c in
            (c.state == .making || c.state == .touching)
                && c.size >= baseTunables.minContactSize
                && c.size <= baseTunables.palmSizeThreshold
        }

        if active.isEmpty {
            let events = attemptActive ? finishAttempt() : []
            attemptActive = false
            return events
        }

        attemptActive = true
        attemptMaxSimultaneous = max(attemptMaxSimultaneous, active.count)
        if active.count == 3 {
            let cx = active.reduce(0.0) { $0 + $1.x } / 3
            let cy = active.reduce(0.0) { $0 + $1.y } / 3
            episode.append((cx, cy))
        } else {
            closeEpisode()
        }
        return []
    }

    // MARK: - Attempt lifecycle

    private func finishAttempt() -> [Event] {
        closeEpisode()
        defer {
            attemptMaxSimultaneous = 0
            attemptRecognizedDirection = nil
            bestEpisodeVector = nil
        }

        guard let step = currentStep else { return [] }
        // Noise (never reached 3 fingers, or barely moved) consumes no attempt.
        let vector = bestEpisodeVector
        let magnitude = vector.map { max(abs($0.dx), abs($0.dy)) } ?? 0
        guard attemptMaxSimultaneous >= 3, magnitude >= 0.05 else { return [] }

        attemptNumber += 1
        var events: [Event] = []

        let recognized = attemptRecognizedDirection == step.gesture
        if recognized {
            recognizedInStep += 1
            events.append(.attemptRecognized(step: step.gesture, attempt: attemptNumber))
        } else {
            events.append(.attemptMissed(step: step.gesture, attempt: attemptNumber,
                                         measuredAngle: vector.map(angleDegrees)))
        }
        collectEvidence(for: step.gesture, vector: vector)

        if attemptNumber >= step.attemptsRequired {
            let accuracy = Double(recognizedInStep) / Double(step.attemptsRequired)
            accuracies[step.gesture] = accuracy
            events.append(.stepCompleted(step.gesture, accuracy: accuracy))
            stepIndex += 1
            attemptNumber = 0
            recognizedInStep = 0
            if stepIndex < steps.count {
                currentStep = steps[stepIndex]
            } else {
                currentStep = nil
                events.append(.sessionCompleted(makeResult()))
            }
        }
        return events
    }

    private func closeEpisode() {
        defer { episode = [] }
        guard episode.count >= 5, let first = episode.first, let last = episode.last else { return }
        let dx = last.x - first.x
        let dy = last.y - first.y
        let magnitude = max(abs(dx), abs(dy))
        let bestMagnitude = bestEpisodeVector.map { max(abs($0.dx), abs($0.dy)) } ?? 0
        if magnitude > bestMagnitude {
            bestEpisodeVector = (dx, dy)
        }
    }

    // MARK: - Evidence → suggestion

    private func collectEvidence(for gesture: GestureDirection, vector: (dx: Double, dy: Double)?) {
        guard let vector, abs(vector.dx) > 0.001 || abs(vector.dy) > 0.001 else { return }
        switch gesture {
        case .left, .right:
            // Attempt clearly meant horizontally (≤55° tilt) → the dominance value
            // that would just accept it.
            guard abs(vector.dy) > 0.001 else {
                requiredHorizontalDominance.append(Self.horizontalDominanceRange.upperBound)
                return
            }
            let tilt = abs(atan2(vector.dy, abs(vector.dx))) * 180 / .pi
            if tilt <= 55 {
                requiredHorizontalDominance.append(abs(vector.dx) / abs(vector.dy))
            }
        case .up:
            guard abs(vector.dx) > 0.001 else {
                requiredVerticalDominance.append(Self.verticalDominanceRange.upperBound)
                return
            }
            let offVertical = abs(atan2(vector.dx, abs(vector.dy))) * 180 / .pi
            if offVertical <= 55 {
                requiredVerticalDominance.append(abs(vector.dy) / abs(vector.dx))
            }
        }
    }

    private func makeResult() -> CalibrationResult {
        var suggested = baseTunables
        if let needed = requiredHorizontalDominance.min() {
            let relaxed = min(baseTunables.horizontalDominance, needed * Self.dominanceMargin)
            suggested.horizontalDominance = relaxed.clamped(to: Self.horizontalDominanceRange)
        }
        if let needed = requiredVerticalDominance.min() {
            let relaxed = min(baseTunables.verticalDominance, needed * Self.dominanceMargin)
            suggested.verticalDominance = relaxed.clamped(to: Self.verticalDominanceRange)
        }
        return CalibrationResult(suggested: suggested, stepAccuracies: accuracies)
    }

    private func angleDegrees(_ vector: (dx: Double, dy: Double)) -> Double {
        var angle = atan2(vector.dy, vector.dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        return angle
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// Outcome of a completed calibration session.
public struct CalibrationResult: Equatable, Sendable {
    public var suggested: Tunables
    public var stepAccuracies: [GestureDirection: Double]

    public init(suggested: Tunables, stepAccuracies: [GestureDirection: Double]) {
        self.suggested = suggested
        self.stepAccuracies = stepAccuracies
    }
}
