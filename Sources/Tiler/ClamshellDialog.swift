import AppKit
import SwiftUI

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

@MainActor final class ClamshellDialogModel: ObservableObject {
    @Published var selectedMinutes: Int   // 0 = until stopped, else minutes
    private(set) var confirmed = false
    var onFinish: (() -> Void)?

    init(preselectMinutes: Int) { selectedMinutes = preselectMinutes }

    func finish(confirmed: Bool) {
        self.confirmed = confirmed
        onFinish?()
    }
}

/// The lid-closed start dialog, styled like the Guide/About window (centered card):
/// warning image, heat copy, a duration picker (reusing the menu's timers), Start/Cancel.
struct ClamshellDialogView: View {
    @ObservedObject var model: ClamshellDialogModel

    private let options: [(String, Int)] = [
        ("Until stopped", 0), ("10 minutes", 10), ("30 minutes", 30), ("1 hour", 60),
        ("2 hours", 120), ("5 hours", 300), ("10 hours", 600), ("24 hours", 1440),
    ]

    var body: some View {
        VStack(spacing: 14) {
            ClamshellWarningImage().frame(width: 76, height: 76)
            Text("Prevent sleep with the lid closed")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("The Mac keeps running folded — it gets hot, so never leave it in a bag. "
                 + "Starting this asks for an administrator password.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("Keep awake for:")
                Picker("", selection: $model.selectedMinutes) {
                    ForEach(options, id: \.1) { Text($0.0).tag($0.1) }
                }
                .labelsHidden()
                .frame(width: 130)
            }
            .padding(.top, 2)
            HStack(spacing: 12) {
                Button("Cancel") { model.finish(confirmed: false) }
                    .keyboardShortcut(.cancelAction)
                Button("Start") { model.finish(confirmed: true) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .frame(width: 340)
    }
}
