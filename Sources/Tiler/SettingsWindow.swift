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
    @Published var windowHotkeysEnabled: Bool {
        didSet { store.windowHotkeysEnabled = windowHotkeysEnabled }
    }
    @Published var utilityHotkeysEnabled: Bool {
        didSet { store.utilityHotkeysEnabled = utilityHotkeysEnabled }
    }
    @Published var accessibilityGranted: Bool
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }
    @Published var conflicts: [SystemConflict] = []
    @Published var isCalibrated: Bool

    // Power (add-power-control)
    @Published var keepDisplayAwake: Bool {
        didSet { store.keepDisplayAwake = keepDisplayAwake }
    }
    @Published var batteryFloorPercent: Int {
        didSet { store.batteryFloorPercent = batteryFloorPercent }
    }
    @Published var deepSleepOnBattery: Bool {
        didSet {
            store.deepSleepOnBattery = deepSleepOnBattery
            // Suppressed while reflecting the actual pmset state back (revert-on-cancel).
            if !isReflectingDeepSleep { onDeepSleepToggle?(deepSleepOnBattery) }
        }
    }
    /// Drives the admin-authorized profile apply/restore (wired in task 3.1).
    var onDeepSleepToggle: ((Bool) -> Void)?
    private var isReflectingDeepSleep = false

    @Published var debugLogging: Bool {
        didSet {
            store.powerDebugLogging = debugLogging
            onDebugLoggingToggle?(debugLogging)
        }
    }
    var onDebugLoggingToggle: ((Bool) -> Void)?
    var onRevealDebugLog: (() -> Void)?

    var onCalibrate: (() -> Void)?

    private let store: SettingsStore

    init(store: SettingsStore, accessibilityGranted: Bool) {
        self.store = store
        gesturesEnabled = store.gesturesEnabled
        windowHotkeysEnabled = store.windowHotkeysEnabled
        utilityHotkeysEnabled = store.utilityHotkeysEnabled
        self.accessibilityGranted = accessibilityGranted
        launchAtLogin = SMAppService.mainApp.status == .enabled
        isCalibrated = store.tunablesOverride != nil
        keepDisplayAwake = store.keepDisplayAwake
        batteryFloorPercent = store.batteryFloorPercent
        deepSleepOnBattery = store.deepSleepOnBattery
        debugLogging = store.powerDebugLogging
        refreshConflicts()
    }

    /// Set the toggle to the actual system state without re-triggering the profile
    /// write (used to revert on a cancelled/failed authorization).
    func reflectDeepSleep(_ actual: Bool) {
        isReflectingDeepSleep = true
        deepSleepOnBattery = actual
        isReflectingDeepSleep = false
    }

    func startCalibration() {
        onCalibrate?()
    }

    func resetCalibration() {
        store.tunablesOverride = nil
        isCalibrated = false
    }

    func refreshCalibrationState() {
        isCalibrated = store.tunablesOverride != nil
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

/// Settings window (settings spec): tabbed to stay compact — General (permission +
/// toggles) and Gestures (conflicts + calibration), the macOS-idiomatic pattern for
/// small preference windows, so nothing needs to scroll.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        // Explicit height is mandatory: Form is List-backed and reports no
        // intrinsic height, so a bare TabView collapses to an empty strip.
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            gesturesTab
                .tabItem { Label("Gestures", systemImage: "hand.point.up.left") }
            powerTab
                .tabItem { Label("Power", systemImage: "bolt") }
        }
        .frame(width: 460, height: 320)
        .padding(12)
    }

    private var powerTab: some View {
        Form {
            Section("Prevent Sleep") {
                Toggle("Keep display awake too", isOn: $model.keepDisplayAwake)
                Picker("Stop when battery below", selection: $model.batteryFloorPercent) {
                    Text("Off").tag(0)
                    Text("30%").tag(30)
                    Text("20%").tag(20)
                    Text("10%").tag(10)
                }
            }
            Section("Deep Sleep") {
                Toggle("Deep Sleep on lid close (battery)", isOn: $model.deepSleepOnBattery)
                Text("Sleep on battery writes memory to disk and powers it off — "
                     + "near-zero drain, wake takes 10–20 s. Changing this asks for "
                     + "an administrator password.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Diagnostics") {
                Toggle("Debug logging", isOn: $model.debugLogging)
                HStack {
                    Text("Records power events to a log file. Low overhead — safe to leave on for days.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reveal Log") { model.onRevealDebugLog?() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section { permissionRow }
            Section("Control") {
                Toggle("Enable trackpad gestures", isOn: $model.gesturesEnabled)
                Toggle("Window tiling hotkeys (⌃⇧ arrows)", isOn: $model.windowHotkeysEnabled)
                Toggle("Lock screen hotkey (⌃A)", isOn: $model.utilityHotkeysEnabled)
                Toggle("Launch at login", isOn: $model.launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }

    private var gesturesTab: some View {
        Form {
            Section("Calibration") {
                LabeledContent(model.isCalibrated
                    ? "Personal gesture thresholds active"
                    : "Tune gesture thresholds to your hand") {
                    Button("Calibrate…") { model.startCalibration() }
                }
                if model.isCalibrated {
                    Button("Reset to defaults") { model.resetCalibration() }
                }
            }
            Section("System gesture conflicts") {
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
        }
        .formStyle(.grouped)
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
