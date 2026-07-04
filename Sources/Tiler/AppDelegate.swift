import AppKit
import SwiftUI
import TilerCore
import TilerSystem

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let version = "0.2.0-dev"

    private var statusItem: NSStatusItem?
    private var touchStream: TouchStream?
    private var engine: GestureEngine?
    private var hotkeys: HotkeyController?
    private var permissionMonitor: PermissionMonitor?
    private let windowActions = WindowActions()
    private let settings = SettingsStore()

    private var settingsModel: SettingsModel?
    private var aboutWindow: AuxWindow<AboutView>?
    private var settingsWindow: AuxWindow<SettingsView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPermissionMonitor()
        setUpHotkeys()
        setUpSettingsWiring()
        startTouchPipeline()
        runStartupPermissionFlow()
        handleDebugWindowArgs()
    }

    /// Headless UI smoke: `--show-settings` / `--show-about` open the windows at
    /// launch so scripts can verify they construct without a human click.
    private func handleDebugWindowArgs() {
        let args = CommandLine.arguments
        if args.contains("--show-settings") { showSettings() }
        if args.contains("--show-about") { showAbout() }
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

    private func applyPermissionState(_ trusted: Bool) {
        statusItem?.button?.title = trusted ? "▦" : "▦⚠︎"
        settingsModel?.accessibilityGranted = trusted
        NSLog("Tiler: accessibility %@", trusted ? "granted" : "missing")
    }

    /// Startup flow (app-shell spec): without permission the user lands one click
    /// away from the fix — Settings window with the highlighted row.
    private func runStartupPermissionFlow() {
        if !(permissionMonitor?.trusted ?? false) {
            showSettings()
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
            NSLog("Tiler: settings — gestures %@, hotkeys %@",
                  store.gesturesEnabled ? "on" : "off",
                  store.hotkeysEnabled ? "on" : "off")
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
        let engine = GestureEngine(recorder: makeRecorderIfRequested()) { [weak self] action in
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
        guard settings.gesturesEnabled else { return }
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
        item.button?.title = "▦"

        let menu = NSMenu()
        menu.addItem(makeItem("About Tiler", #selector(showAbout)))
        let settingsItem = makeItem("Settings…", #selector(showSettingsAction))
        settingsItem.keyEquivalent = ","
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Tiler",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        item.menu = menu
        statusItem = item
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showAbout() {
        if aboutWindow == nil {
            aboutWindow = AuxWindow(title: "About Tiler") { AboutView() }
        }
        aboutWindow?.show()
        NSLog("Tiler: about window shown")
    }

    @objc private func showSettingsAction() {
        showSettings()
    }

    private func showSettings() {
        if settingsModel == nil {
            settingsModel = SettingsModel(
                store: settings,
                accessibilityGranted: permissionMonitor?.trusted ?? false
            )
        }
        settingsModel?.refreshConflicts()
        if settingsWindow == nil, let model = settingsModel {
            settingsWindow = AuxWindow(title: "Tiler Settings") { SettingsView(model: model) }
        }
        settingsWindow?.show()
        NSLog("Tiler: settings window shown")
    }
}
