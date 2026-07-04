import AppKit
import TilerCore
import TilerSystem

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var touchStream: TouchStream?
    private var engine: GestureEngine?
    private var hotkeys: HotkeyController?
    private var permissionMonitor: PermissionMonitor?
    private let windowActions = WindowActions()

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
                self?.statusItem?.button?.title = trusted ? "▦" : "▦⚠︎"
                NSLog("Tiler: accessibility %@", trusted ? "granted" : "missing")
            }
        )
        monitor.start()
        permissionMonitor = monitor
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

    // MARK: - UI

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "▦"
        let menu = NSMenu()
        let versionItem = NSMenuItem(title: "Tiler 0.1.0-dev", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Tiler",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        item.menu = menu
        statusItem = item
    }
}
