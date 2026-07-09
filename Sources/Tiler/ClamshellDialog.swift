import AppKit
import SwiftUI

/// "≈ 2 h 55 min from now" for a target end date (empty when in the past).
func fromNowDescription(_ end: Date) -> String {
    let seconds = end.timeIntervalSinceNow
    guard seconds >= 60 else { return "less than a minute from now" }
    let minutes = Int((seconds / 60).rounded(.down))
    let text: String
    if minutes >= 120 {
        let h = minutes / 60, m = minutes % 60
        text = m == 0 ? "\(h) h" : "\(h) h \(m) min"
    } else {
        text = "\(minutes) min"
    }
    return "≈ \(text) from now"
}

/// Duration options shared by the lid-closed dialog and the "Until a specific time"
/// flow. Tag: 0 = until stopped, -1 = until a specific end date/time, else minutes.
enum PowerDuration {
    static let untilTimeTag = -1
    static let picker: [(String, Int)] = [
        ("Until stopped", 0), ("10 minutes", 10), ("30 minutes", 30), ("1 hour", 60),
        ("2 hours", 120), ("5 hours", 300), ("10 hours", 600), ("24 hours", 1440),
        ("Until a specific time", untilTimeTag),
    ]

    /// Resolve a picker tag (+ end date for the until-time case) to a session duration
    /// (nil = indefinite). Until-time is clamped to at least a minute.
    static func duration(tag: Int, endDate: Date) -> TimeInterval? {
        switch tag {
        case 0: return nil
        case untilTimeTag: return max(60, endDate.timeIntervalSinceNow)
        default: return TimeInterval(tag) * 60
        }
    }
}

/// Heat-warning graphic for the lid-closed dialog (owner pick, variant 5): a laptop in
/// a bag, crossed out by the red prohibitory sign — "never run closed in a bag".
struct ClamshellWarningImage: View {
    var body: some View {
        ZStack {
            Image(systemName: "bag.fill").font(.system(size: 46)).foregroundStyle(.secondary)
            Image(systemName: "laptopcomputer").font(.system(size: 18)).foregroundStyle(.white).offset(y: 3)
            Image(systemName: "nosign").font(.system(size: 60)).foregroundStyle(Color(nsColor: .systemRed))
        }
    }
}

// MARK: - "Until a specific time" dialog (normal Prevent Sleep menu)

@MainActor final class UntilTimeDialogModel: ObservableObject {
    @Published var endDate: Date
    private(set) var confirmed = false
    var onFinish: (() -> Void)?

    init(defaultEnd: Date) { endDate = defaultEnd }
    func finish(confirmed: Bool) { self.confirmed = confirmed; onFinish?() }
}

struct UntilTimeDialogView: View {
    @ObservedObject var model: UntilTimeDialogModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 40)).foregroundStyle(Color.accentColor)
            Text("Prevent sleep until a set time").font(.headline)
            DatePicker("Ends:", selection: $model.endDate, in: Date()...,
                       displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.field)
                .fixedSize()
            Text(fromNowDescription(model.endDate))
                .font(.callout).foregroundStyle(.secondary)
            dialogButtons(cancel: { model.finish(confirmed: false) },
                          start: { model.finish(confirmed: true) })
        }
        .padding(24).frame(width: 340)
    }
}

// MARK: - Lid-closed dialog (with the until-time option)

@MainActor final class ClamshellDialogModel: ObservableObject {
    @Published var selectedTag: Int
    @Published var endDate: Date
    private(set) var confirmed = false
    var onFinish: (() -> Void)?

    init(preselectTag: Int, defaultEnd: Date) {
        selectedTag = preselectTag
        endDate = defaultEnd
    }

    func finish(confirmed: Bool) { self.confirmed = confirmed; onFinish?() }
    func resolvedDuration() -> TimeInterval? {
        PowerDuration.duration(tag: selectedTag, endDate: endDate)
    }
}

struct ClamshellDialogView: View {
    @ObservedObject var model: ClamshellDialogModel

    var body: some View {
        VStack(spacing: 14) {
            ClamshellWarningImage().frame(width: 76, height: 76)
            Text("Prevent sleep with the lid closed")
                .font(.headline).multilineTextAlignment(.center)
            Text("The Mac keeps running folded — it gets hot, so never leave it in a bag. "
                 + "Starting this asks for an administrator password.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Label("When a timer ends, the Mac is put to sleep for you — the first time, "
                  + "macOS may ask to allow Tiler to control System Events.",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("Keep awake for:")
                Picker("", selection: $model.selectedTag) {
                    ForEach(PowerDuration.picker, id: \.1) { Text($0.0).tag($0.1) }
                }
                .labelsHidden().frame(width: 160)
            }
            if model.selectedTag == PowerDuration.untilTimeTag {
                DatePicker("Ends:", selection: $model.endDate, in: Date()...,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.field).fixedSize()
                Text(fromNowDescription(model.endDate))
                    .font(.caption).foregroundStyle(.secondary)
            }
            dialogButtons(cancel: { model.finish(confirmed: false) },
                          start: { model.finish(confirmed: true) })
        }
        .padding(24).frame(width: 360)
    }
}

/// Cancel (esc) + default Start buttons, shared by both dialogs.
@ViewBuilder
func dialogButtons(cancel: @escaping () -> Void, start: @escaping () -> Void) -> some View {
    HStack(spacing: 12) {
        Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
        Button("Start", action: start).keyboardShortcut(.defaultAction)
    }
    .padding(.top, 6)
}
