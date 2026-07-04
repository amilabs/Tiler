import AppKit
import SwiftUI
import TilerCore
import TilerSystem

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let version = "0.2.0-dev"

    private var statusItem: NSStatusItem?
    private var touchStream: TouchStream?
    private var engine: GestureEngine?
    private var hotkeys: HotkeyController?
    private var permissionMonitor: PermissionMonitor?
    private let windowActions = WindowActions()
    private let settings = SettingsStore()
    private let diagnostics = ConflictDiagnostics()

    private var settingsModel: SettingsModel?
    private var settingsWindow: AuxWindow<SettingsView>?
    private var guideModel: GuideModel?
    private var guideWindow: AuxWindow<GuideView>?
    private var calibrationWindow: NSWindow?
    private var calibrationModel: CalibrationModel?
    private var calibrationActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPermissionMonitor()
        setUpHotkeys()
        setUpSettingsWiring()
        startTouchPipeline()
        runStartupPermissionFlow()
        handleDebugWindowArgs()
    }

    /// Headless UI smoke: `--show-settings` / `--show-about` / `--show-calibration`
    /// open the windows at launch so scripts can verify they construct without a click.
    private func handleDebugWindowArgs() {
        let args = CommandLine.arguments
        if args.contains("--show-settings") { showSettings() }
        if args.contains("--show-calibration") { showCalibration() }
        if args.contains("--show-guide") || args.contains("--show-about") { showGuide() }
    }

    // MARK: - Calibration

    private func showCalibration() {
        guard let engine else { return }
        calibrationActive = true
        let model = CalibrationModel(engine: engine) { [weak self] result in
            guard let self else { return }
            if let result {
                self.settings.tunablesOverride = result.suggested
                NSLog("Tiler: calibration applied (horizontal %.2f, vertical %.2f)",
                      result.suggested.horizontalDominance, result.suggested.verticalDominance)
            }
            self.calibrationActive = false
            self.calibrationWindow?.close()
            self.calibrationWindow = nil
            self.calibrationModel = nil
        }
        calibrationModel = model

        let hosting = NSHostingController(rootView: CalibrationView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Gesture Calibration"
        window.styleMask = [.titled]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        calibrationWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSLog("Tiler: calibration window shown")
    }

    // MARK: - Permissions

    private func setUpPermissionMonitor() {
        // One-time system prompt on first launch (permissions spec).
        // Literal key: kAXTrustedCheckOptionPrompt is a C global var, unusable
        // under Swift 6 strict concurrency.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

        let monitor = PermissionMonitor(
            pollInterval: Tunables.default.permissionPollInterval,
            check: { AXIsProcessTrusted() },
            onChange: { [weak self] trusted in
                self?.applyPermissionState(trusted)
            }
        )
        monitor.start()
        permissionMonitor = monitor
    }

    private var conflictsPresent = false

    private func applyPermissionState(_ trusted: Bool) {
        settingsModel?.accessibilityGranted = trusted
        guideModel?.accessibilityGranted = trusted
        updateStatusGlyph()
        NSLog("Tiler: accessibility %@", trusted ? "granted" : "missing")
    }

    /// Re-reads system trackpad settings; alerts (glyph + log) when they compete
    /// with Tiler's gestures. Called at launch and every time the menu opens.
    private func refreshConflictAlert() {
        let conflicts = diagnostics.conflicts()
        if conflicts.isEmpty != !conflictsPresent {
            NSLog("Tiler: system gesture conflicts: %d", conflicts.count)
        }
        conflictsPresent = !conflicts.isEmpty
        updateStatusGlyph()
    }

    private func updateStatusGlyph() {
        let trusted = permissionMonitor?.trusted ?? false
        let alert = !trusted || conflictsPresent
        statusItem?.button?.title = alert ? " ⚠︎" : ""
        statusItem?.button?.toolTip = !trusted
            ? "Tiler: Accessibility permission missing"
            : (conflictsPresent
                ? "Tiler: conflicting system trackpad gestures detected — see Shortcuts & Help"
                : "Tiler")
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshConflictAlert()
    }

    /// Startup flow v2 (add-onboarding-guide): first launch ever, launch without
    /// permission, or launch with conflicting system gestures lands on the Guide.
    private func runStartupPermissionFlow() {
        refreshConflictAlert()
        if !settings.hasSeenGuide || !(permissionMonitor?.trusted ?? false) || conflictsPresent {
            showGuide()
        }
    }

    // MARK: - Hotkeys & settings wiring

    private func setUpHotkeys() {
        let controller = HotkeyController()
        controller.handler = { [weak self] command in
            self?.execute(command)
        }
        if settings.hotkeysEnabled {
            controller.registerAll()
        }
        hotkeys = controller
    }

    private func setUpSettingsWiring() {
        settings.onChange = { [weak self] store in
            guard let self else { return }
            if store.hotkeysEnabled {
                self.hotkeys?.registerAll()
            } else {
                self.hotkeys?.unregisterAll()
            }
            self.engine?.stageTunables(store.effectiveTunables)
            NSLog("Tiler: settings — gestures %@, hotkeys %@, calibrated %@",
                  store.gesturesEnabled ? "on" : "off",
                  store.hotkeysEnabled ? "on" : "off",
                  store.tunablesOverride == nil ? "no" : "yes")
        }
    }

    private func execute(_ command: TilingCommand) {
        if !windowActions.perform(command) {
            // Failed AX action: cheap revocation/permission re-check.
            permissionMonitor?.noteActionFailed()
        }
    }

    // MARK: - Touch pipeline

    private func startTouchPipeline() {
        let engine = GestureEngine(
            recorder: makeRecorderIfRequested(),
            tunables: settings.effectiveTunables
        ) { [weak self] action in
            Task { @MainActor in
                self?.route(action)
            }
        }
        self.engine = engine
        do {
            let stream = try TouchStream { frame in
                engine.handle(frame)
            }
            try stream.start()
            touchStream = stream
            NSLog("Tiler: touch stream started")
        } catch {
            // No trackpad / framework change: gestures unavailable, app stays alive.
            NSLog("Tiler: touch stream unavailable: \(error)")
        }
    }

    private func route(_ action: GestureAction) {
        guard settings.gesturesEnabled, !calibrationActive else { return }
        NSLog("Tiler: gesture %@ nextDisplay=%d", action.direction.rawValue, action.nextDisplay ? 1 : 0)
        let command: TilingCommand
        switch action.direction {
        case .left: command = .leftHalf(nextDisplay: action.nextDisplay)
        case .right: command = .rightHalf(nextDisplay: action.nextDisplay)
        case .up: command = .maximize
        }
        execute(command)
    }

    private func makeRecorderIfRequested() -> TraceRecorder? {
        let args = CommandLine.arguments
        guard let flagIndex = args.firstIndex(of: "--record-touches"),
              args.indices.contains(flagIndex + 1) else { return nil }
        let path = args[flagIndex + 1]
        do {
            let recorder = try TraceRecorder(path: path)
            NSLog("Tiler: recording touches to \(path)")
            return recorder
        } catch {
            NSLog("Tiler: cannot open trace file \(path): \(error)")
            return nil
        }
    }

    // MARK: - Menu (app-shell spec: About / Settings… / Quit)

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Same glyph family as the app icon (owner pick #6); auto-templates for
        // menu bar light/dark. The ⚠︎ title appears next to it when unpermitted.
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        item.button?.image = NSImage(systemSymbolName: "hand.pinch.fill",
                                     accessibilityDescription: "Tiler")?
            .withSymbolConfiguration(config)
        item.button?.imagePosition = .imageLeft

        let menu = NSMenu()
        menu.addItem(makeItem("Tiler…", #selector(showGuideAction)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Tiler",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showSettingsAction() {
        showSettings()
    }

    @objc private func showGuideAction() {
        showGuide()
    }

    private func showGuide() {
        settings.hasSeenGuide = true
        if guideModel == nil {
            let model = GuideModel(accessibilityGranted: permissionMonitor?.trusted ?? false)
            model.onOpenAccessibility = { [weak self] in self?.openAccessibilitySettings() }
            model.onCalibrate = { [weak self] in self?.showCalibration() }
            model.onOpenSettings = { [weak self] in self?.showSettings() }
            guideModel = model
        }
        guideModel?.refreshConflicts()
        if guideWindow == nil, let model = guideModel {
            guideWindow = AuxWindow(title: "About Tiler") { GuideView(model: model) }
        }
        guideWindow?.show()
        NSLog("Tiler: guide window shown")
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func showSettings() {
        if settingsModel == nil {
            settingsModel = SettingsModel(
                store: settings,
                accessibilityGranted: permissionMonitor?.trusted ?? false
            )
            settingsModel?.onCalibrate = { [weak self] in
                self?.showCalibration()
            }
        }
        settingsModel?.refreshConflicts()
        if settingsWindow == nil, let model = settingsModel {
            settingsWindow = AuxWindow(title: "Tiler Settings") { SettingsView(model: model) }
        }
        settingsWindow?.show()
        NSLog("Tiler: settings window shown")
    }
}
