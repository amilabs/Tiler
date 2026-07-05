import AppKit
import SwiftUI
import TilerCore
import TilerSystem

/// Drives a CalibrationSession from the live touch stream (calibration spec).
@MainActor
final class CalibrationModel: ObservableObject {
    struct AttemptMark: Identifiable {
        let id: Int
        let recognized: Bool
        let angle: Double?
    }

    @Published private(set) var prompt: CalibrationSession.Step?
    @Published private(set) var attempts: [AttemptMark] = []
    @Published private(set) var stepAccuracy: Double?
    @Published private(set) var result: CalibrationResult?
    @Published private(set) var stepNumber = 1
    @Published private(set) var stepCount = 1

    var accuracySoFar: Double {
        guard !attempts.isEmpty else { return 1 }
        return Double(attempts.filter(\.recognized).count) / Double(attempts.count)
    }

    /// Fraction of the current step already done (for the overall progress bar).
    var stepFraction: Double {
        guard let prompt, prompt.attemptsRequired > 0 else { return 0 }
        return Double(attempts.count) / Double(prompt.attemptsRequired)
    }

    private var session: CalibrationSession
    private let engine: GestureEngine
    private let onFinish: (CalibrationResult?) -> Void

    init(engine: GestureEngine, onFinish: @escaping (CalibrationResult?) -> Void) {
        self.engine = engine
        self.onFinish = onFinish
        session = CalibrationSession()
        prompt = session.currentStep
        stepNumber = session.stepNumber
        stepCount = session.stepCount
        attachTap()
    }

    private func attachTap() {
        engine.setFrameTap { [weak self] frame in
            Task { @MainActor in
                self?.feed(frame)
            }
        }
    }

    private func feed(_ frame: TouchFrame) {
        for event in session.process(frame) {
            apply(event)
        }
    }

    private func apply(_ event: CalibrationSession.Event) {
        switch event {
        case .attemptRecognized(_, let attempt):
            attempts.append(AttemptMark(id: attempt, recognized: true, angle: nil))
        case .attemptMissed(_, let attempt, let angle):
            attempts.append(AttemptMark(id: attempt, recognized: false, angle: angle))
        case .stepCompleted(_, let accuracy):
            stepAccuracy = accuracy
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                self.attempts = []
                self.stepAccuracy = nil
                self.prompt = self.session.currentStep
                self.stepNumber = self.session.stepNumber
            }
        case .sessionCompleted(let result):
            self.result = result
            self.prompt = nil
            engine.setFrameTap(nil)
        }
    }

    func restart() {
        session = CalibrationSession()
        attempts = []
        stepAccuracy = nil
        result = nil
        prompt = session.currentStep
        stepNumber = session.stepNumber
        stepCount = session.stepCount
        attachTap()
    }

    func finish(apply: Bool) {
        engine.setFrameTap(nil)
        onFinish(apply ? result : nil)
    }
}

/// Capsule progress bar: same look as ProgressView, but rasterizes correctly
/// under ImageRenderer (release screenshots) and renders deterministically.
struct ProgressBar: View {
    let value: Double
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.22))
                Capsule().fill(tint)
                    .frame(width: max(6, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 6)
    }
}

/// Calibration dialog: animated gesture demo, live attempt feedback, accuracy.
struct CalibrationView: View {
    @ObservedObject var model: CalibrationModel

    var body: some View {
        VStack(spacing: 16) {
            if let result = model.result {
                summary(result)
            } else if let prompt = model.prompt {
                activeStep(prompt)
            } else {
                ProgressView()
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    @ViewBuilder
    private func activeStep(_ prompt: CalibrationSession.Step) -> some View {
        HStack {
            Text(title(for: prompt.gesture))
                .font(.title3.weight(.medium))
            Spacer()
            Text("Step \(model.stepNumber) of \(model.stepCount)")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.vertical, 3)
                .padding(.horizontal, 9)
                .background(Color.secondary.opacity(0.12), in: Capsule())
        }
        ProgressBar(value: (Double(model.stepNumber - 1) + model.stepFraction)
            / Double(max(1, model.stepCount)))
        GestureDemoView(direction: prompt.gesture)
            .frame(height: 110)
        Text("Swipe with exactly three fingers, \(prompt.attemptsRequired) times.")
            .font(.callout)
            .foregroundStyle(.secondary)

        HStack(spacing: 8) {
            ForEach(0..<prompt.attemptsRequired, id: \.self) { i in
                Circle()
                    .fill(color(forAttempt: i))
                    .frame(width: 14, height: 14)
            }
            Text("Attempt \(min(model.attempts.count + 1, prompt.attemptsRequired)) of \(prompt.attemptsRequired)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        if let last = model.attempts.last, !last.recognized {
            Text(missText(last))
                .font(.caption)
                .foregroundStyle(.orange)
        }
        ProgressBar(value: model.accuracySoFar,
                    tint: model.accuracySoFar > 0.7 ? .green : .orange)
        Text("Accuracy \(Int(model.accuracySoFar * 100)) %")
            .font(.caption)
            .foregroundStyle(.secondary)
        Button("Cancel") { model.finish(apply: false) }
    }

    @ViewBuilder
    private func summary(_ result: CalibrationResult) -> some View {
        Text("Calibration complete")
            .font(.title3.weight(.medium))
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            ForEach(Array(result.stepAccuracies.keys).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { gesture in
                GridRow {
                    Text(title(for: gesture)).foregroundStyle(.secondary)
                    Text("\(Int((result.stepAccuracies[gesture] ?? 0) * 100)) %")
                }
            }
            GridRow {
                Text("Horizontal cone").foregroundStyle(.secondary)
                Text(String(format: "≤ %.0f°", coneDegrees(result.suggested.horizontalDominance)))
            }
            GridRow {
                Text("Vertical cone").foregroundStyle(.secondary)
                Text(String(format: "≤ %.0f°", coneDegrees(result.suggested.verticalDominance)))
            }
        }
        .font(.callout)
        HStack {
            Button("Recalibrate") { model.restart() }
            Spacer()
            Button("Discard") { model.finish(apply: false) }
            Button("Apply") { model.finish(apply: true) }
                .keyboardShortcut(.defaultAction)
        }
    }

    private func color(forAttempt index: Int) -> Color {
        guard index < model.attempts.count else { return Color.secondary.opacity(0.25) }
        return model.attempts[index].recognized ? .green : .red
    }

    private func missText(_ mark: CalibrationModel.AttemptMark) -> String {
        if let angle = mark.angle {
            return String(format: "Missed — movement at %.0f°", angle)
        }
        return "Missed — not recognized as this gesture"
    }

    private func title(for gesture: GestureDirection) -> String {
        switch gesture {
        case .left: "Swipe left"
        case .right: "Swipe right"
        case .up: "Swipe up"
        }
    }

    private func coneDegrees(_ dominance: Double) -> Double {
        atan(1.0 / dominance) * 180 / .pi
    }
}

/// Three-dot demo of a swipe direction. `animated` loops the stroke (use for the
/// active calibration prompt or on hover); otherwise a static mid-stroke pose is
/// drawn — direction stays readable at zero CPU (idle budget).
struct GestureDemoView: View {
    let direction: GestureDirection
    var animated: Bool = true
    @Environment(\.animationsActive) private var animationsActive

    var body: some View {
        if animated && animationsActive {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                demoCanvas(phase: CGFloat(t.truncatingRemainder(dividingBy: 1.4) / 1.4))
            }
        } else {
            demoCanvas(phase: 0.55)
        }
    }

    private func demoCanvas(phase: CGFloat) -> some View {
            Canvas { canvas, size in
                let progress = min(1, max(0, (phase - 0.15) / 0.6))
                let travel: CGFloat = 66
                let offset: CGVector
                switch direction {
                case .left: offset = CGVector(dx: -travel * progress, dy: 0)
                case .right: offset = CGVector(dx: travel * progress, dy: 0)
                case .up: offset = CGVector(dx: 0, dy: -travel * progress)
                }
                let center = CGPoint(x: size.width / 2 - offset.dx / 2,
                                     y: size.height / 2 - offset.dy / 2)
                let spread: CGFloat = 20
                let fade = phase > 0.8 ? 1 - (phase - 0.8) / 0.2 : 1
                for i in -1...1 {
                    let base: CGPoint
                    switch direction {
                    case .left, .right:
                        base = CGPoint(x: center.x, y: center.y + CGFloat(i) * spread)
                    case .up:
                        base = CGPoint(x: center.x + CGFloat(i) * spread, y: center.y)
                    }
                    let dot = CGPoint(x: base.x + offset.dx, y: base.y + offset.dy)
                    // Trail
                    var trail = Path()
                    trail.move(to: base)
                    trail.addLine(to: dot)
                    canvas.stroke(trail, with: .color(.accentColor.opacity(0.25 * fade)),
                                  style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    canvas.fill(Path(ellipseIn: CGRect(x: dot.x - 7, y: dot.y - 7, width: 14, height: 14)),
                                with: .color(.accentColor.opacity(fade)))
                }
            }
    }
}
