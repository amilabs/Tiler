import AppKit
import SwiftUI
import TilerCore
import TilerSystem

/// Single source for the cheat sheet, mirroring the hotkeys/gestures specs.
enum GuideContent {
    struct HotkeyRow: Identifiable {
        let id = UUID()
        let keys: [String]
        let action: String
    }

    struct GestureRow: Identifiable {
        let id = UUID()
        let direction: GestureDirection
        let cmd: Bool
        let action: String
    }

    static let hotkeys: [HotkeyRow] = [
        HotkeyRow(keys: ["⌃", "⇧", "←"], action: "Left half of the current screen"),
        HotkeyRow(keys: ["⌃", "⇧", "→"], action: "Right half of the current screen"),
        HotkeyRow(keys: ["⌃", "⇧", "↑"], action: "Maximize (after a 0.3 s pause)"),
        HotkeyRow(keys: ["⌃", "⇧", "↑", "↑"], action: "Full height, centered, ⅓ width — double press"),
        HotkeyRow(keys: ["⌃", "⇧", "↓"], action: "Restore the window's previous frame"),
        HotkeyRow(keys: ["⌘", "⌃", "⇧", "←"], action: "Left half on the next display"),
        HotkeyRow(keys: ["⌘", "⌃", "⇧", "→"], action: "Right half on the next display"),
    ]

    static let gestures: [GestureRow] = [
        GestureRow(direction: .left, cmd: false, action: "Left half"),
        GestureRow(direction: .right, cmd: false, action: "Right half"),
        GestureRow(direction: .up, cmd: false, action: "Maximize"),
        GestureRow(direction: .left, cmd: true, action: "Left half on the next display"),
        GestureRow(direction: .right, cmd: true, action: "Right half on the next display"),
    ]

    static let gestureFootnote =
        "Exactly three fingers, one confident stroke. Two- and four-finger movements and swipe-down do nothing — by design."
}

@MainActor
final class GuideModel: ObservableObject {
    @Published var accessibilityGranted: Bool
    @Published var conflicts: [SystemConflict] = []

    var onOpenAccessibility: (() -> Void)?
    var onCalibrate: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    init(accessibilityGranted: Bool) {
        self.accessibilityGranted = accessibilityGranted
        refreshConflicts()
    }

    func refreshConflicts() {
        conflicts = ConflictDiagnostics().conflicts()
    }
}

/// "Welcome to Tiler" — description, live permission card, full cheat sheet,
/// troubleshooting (app-shell spec, add-onboarding-guide).
struct GuideView: View {
    @ObservedObject var model: GuideModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            permissionCard
            section("Hotkeys") {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                    ForEach(GuideContent.hotkeys) { row in
                        GridRow {
                            keycaps(row.keys)
                                .gridColumnAlignment(.trailing)
                            Text(row.action)
                                .font(.callout)
                        }
                    }
                }
            }
            section("Trackpad gestures") {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    ForEach(GuideContent.gestures) { row in
                        GridRow {
                            HStack(spacing: 6) {
                                if row.cmd { keycaps(["⌘"]) }
                                GestureDemoView(direction: row.direction)
                                    .frame(width: 84, height: 40)
                                    .background(Color.secondary.opacity(0.08),
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .gridColumnAlignment(.trailing)
                            Text(row.action)
                                .font(.callout)
                        }
                    }
                }
                Text(GuideContent.gestureFootnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            troubleshooting
        }
        .padding(24)
        .frame(width: 560)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text("Tiler")
                    .font(.title2.weight(.medium))
                Text("Snap the active window with hotkeys and precise three-finger trackpad swipes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var permissionCard: some View {
        if model.accessibilityGranted {
            Label("Accessibility is granted — Tiler can move your windows.",
                  systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Tiler needs the Accessibility permission",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text("Without it hotkeys and gestures are recognized but windows won't move. Enable Tiler in the list — this card turns green by itself, no relaunch needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings…") {
                    model.onOpenAccessibility?()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var troubleshooting: some View {
        section("Gestures not working well?") {
            VStack(alignment: .leading, spacing: 8) {
                if model.conflicts.isEmpty {
                    Label("No conflicting system gestures detected.", systemImage: "checkmark.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.conflicts, id: \.title) { conflict in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(conflict.title, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                                .foregroundStyle(.orange)
                            Text(conflict.guidance)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Text("Swipes are tuned to your hand in one minute:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Calibrate…") { model.onCalibrate?() }
                    Spacer()
                    Button("Settings…") { model.onOpenSettings?() }
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func keycaps(_ keys: [String]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 22)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.secondary.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
                    )
            }
        }
    }
}
