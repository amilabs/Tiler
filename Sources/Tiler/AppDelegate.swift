import AppKit
import ServiceManagement
import TilerCore
import TilerSystem

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let version = "0.1.0-dev"

    private var statusItem: NSStatusItem?
    private var touchStream: TouchStream?
    private var engine: GestureEngine?
    private var hotkeys: HotkeyController?
    private var permissionMonitor: PermissionMonitor?
    private let windowActions = WindowActions()
    private let diagnostics = ConflictDiagnostics()
    private var gesturesEnabled = true

    // Menu items that reflect live state.
    private let permissionItem = NSMenuItem(title: "Accessibility: checking…", action: nil, keyEquivalent: "")
    private let gesturesItem = NSMenuItem(title: "Gestures Enabled", action: #selector(toggleGestures), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let diagnosticsMenu = NSMenu(title: "Diagnostics")

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPermissionMonitor()
        setUpHotkeys()
        startTouchPipeline()
    }

    // MARK: - Permissions & hotkeys

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
        permissionItem.title = trusted
            ? "Accessibility: granted"
            : "Accessibility: NOT granted — windows won’t move"
        NSLog("Tiler: accessibility %@", trusted ? "granted" : "missing")
    }

    private func setUpHotkeys() {
        let controller = HotkeyController()
        controller.handler = { [weak self] command in
            self?.execute(command)
        }
        controller.registerAll()
        hotkeys = controller
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
        guard gesturesEnabled else { return }
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

    // MARK: - Menu

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "▦"

        let menu = NSMenu()
        menu.delegate = self

        permissionItem.isEnabled = false
        menu.addItem(permissionItem)
        menu.addItem(makeItem("Open Accessibility Settings…", #selector(openAccessibilitySettings)))
        menu.addItem(.separator())

        gesturesItem.target = self
        gesturesItem.state = .on
        menu.addItem(gesturesItem)

        let diagnosticsItem = NSMenuItem(title: "Diagnostics", action: nil, keyEquivalent: "")
        diagnosticsItem.submenu = diagnosticsMenu
        menu.addItem(diagnosticsItem)
        menu.addItem(.separator())

        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())

        let versionItem = NSMenuItem(title: "Tiler \(Self.version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
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

    /// Refresh dynamic state right before the menu shows.
    func menuWillOpen(_ menu: NSMenu) {
        gesturesItem.state = gesturesEnabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        rebuildDiagnosticsMenu()
    }

    private func rebuildDiagnosticsMenu() {
        diagnosticsMenu.removeAllItems()
        let conflicts = diagnostics.conflicts()
        if conflicts.isEmpty {
            let ok = NSMenuItem(title: "No conflicting system gestures detected", action: nil, keyEquivalent: "")
            ok.isEnabled = false
            diagnosticsMenu.addItem(ok)
        }
        for conflict in conflicts {
            let header = NSMenuItem(title: "⚠︎ \(conflict.title)", action: nil, keyEquivalent: "")
            header.isEnabled = false
            diagnosticsMenu.addItem(header)
            let detail = NSMenuItem(title: conflict.guidance, action: nil, keyEquivalent: "")
            detail.isEnabled = false
            detail.indentationLevel = 1
            diagnosticsMenu.addItem(detail)
        }
    }

    // MARK: - Menu actions

    @objc private func toggleGestures() {
        gesturesEnabled.toggle()
        NSLog("Tiler: gestures %@", gesturesEnabled ? "enabled" : "disabled")
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Fails for unbundled dev binaries; harmless.
            NSLog("Tiler: launch-at-login toggle failed: \(error)")
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
