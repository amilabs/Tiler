import AppKit
import ServiceManagement
import SwiftUI
import TilerSystem

/// Observable bridge between SwiftUI and the app's live state.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var gesturesEnabled: Bool {
        didSet { store.gesturesEnabled = gesturesEnabled }
    }
    @Published var hotkeysEnabled: Bool {
        didSet { store.hotkeysEnabled = hotkeysEnabled }
    }
    @Published var accessibilityGranted: Bool
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }
    @Published var conflicts: [SystemConflict] = []

    private let store: SettingsStore

    init(store: SettingsStore, accessibilityGranted: Bool) {
        self.store = store
        gesturesEnabled = store.gesturesEnabled
        hotkeysEnabled = store.hotkeysEnabled
        self.accessibilityGranted = accessibilityGranted
        launchAtLogin = SMAppService.mainApp.status == .enabled
        refreshConflicts()
    }

    func refreshConflicts() {
        conflicts = ConflictDiagnostics().conflicts()
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Unbundled dev runs can't register; reflect reality back.
            NSLog("Tiler: launch-at-login failed: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// Settings window (settings spec): toggles, permission status with problem
/// highlight, diagnostics, calibration entry point.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                permissionRow
            }
            Section("Control") {
                Toggle("Enable trackpad gestures", isOn: $model.gesturesEnabled)
                Toggle("Enable hotkeys", isOn: $model.hotkeysEnabled)
                Toggle("Launch at login", isOn: $model.launchAtLogin)
            }
            Section("Gesture conflicts") {
                if model.conflicts.isEmpty {
                    Label("No conflicting system gestures detected", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.conflicts, id: \.title) { conflict in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(conflict.title, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text(conflict.guidance)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Calibration") {
                LabeledContent("Tune gesture thresholds to your hand") {
                    Button("Calibrate…") {}
                        .disabled(true)
                }
                Text("Coming in this release — guided per-gesture calibration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var permissionRow: some View {
        if model.accessibilityGranted {
            Label("Accessibility permission granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Accessibility permission missing", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.headline)
                Text("Tiler can't move windows until you enable it in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Accessibility Settings…") {
                    NSWorkspace.shared.open(URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
