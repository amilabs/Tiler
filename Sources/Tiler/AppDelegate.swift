import AppKit
import SwiftUI
import TilerCore
import TilerSystem

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let version = "0.2.6"

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
    private var settingsMenuItem: NSMenuItem?
    private var guideModel: GuideModel?
    private var guideWindow: AuxWindow<GuideView>?
    private var calibrationWindow: NSWindow?
    private var calibrationModel: CalibrationModel?
    private var calibrationActive = false

    // MARK: - Power (add-power-control)
    private var powerPolicy = PowerPolicy(displayAwake: false, floorPercent: 20)
    private var awake: AwakeController?
    private var powerMonitor: PowerSourceMonitor?
    private var powerTick: DispatchSourceTimer?
    private let powerNotifier = PowerNotifier()
    private var governor: DisableSleepGovernor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPermissionMonitor()
        setUpHotkeys()
        setUpSettingsWiring()
        startTouchPipeline()
        runStartupPermissionFlow()
        setUpPower()
        handleDebugWindowArgs()
    }

    /// Headless UI smoke: `--show-settings` / `--show-about` / `--show-calibration`
    /// open the windows at launch so scripts can verify they construct without a click.
    private func handleDebugWindowArgs() {
        let args = CommandLine.arguments
        if args.contains("--show-settings") { showSettings() }
        if args.contains("--show-calibration") { showCalibration() }
        if args.contains("--show-guide") || args.contains("--show-about") { showGuide() }
        if let i = args.firstIndex(of: "--render-shots"), args.indices.contains(i + 1) {
            renderShots(to: args[i + 1])
        }
        // Power acceptance hooks: `--power-start 30m|2h|inf`, `--power-stop`.
        if let i = args.firstIndex(of: "--power-start"), args.indices.contains(i + 1) {
            let d: TimeInterval? = args[i + 1] == "inf" ? nil
                : Double(args[i + 1].dropLast()).map { args[i + 1].hasSuffix("h") ? $0 * 3600 : $0 * 60 }
            powerApply(.start(clamshell: false, duration: d))
        }
        if args.contains("--power-stop") { powerApply(.stop) }
        // Harness: open the animated window, close it after 2 s — post-close idle
        // CPU must be back under budget (the retained-animations regression).
        if args.contains("--exercise-ui") {
            showGuide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.guideWindow?.close()
                NSLog("Tiler: exercise-ui window closed")
            }
        }
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
                ? "Tiler: conflicting system trackpad gestures detected — see Tiler…"
                : "Tiler")
        // Settings item carries the permission alert (stabilize-menu spec).
        settingsMenuItem?.title = trusted ? "Settings" : "Settings ⚠︎"
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
        controller.apply(windowTiling: settings.windowHotkeysEnabled,
                         utility: settings.utilityHotkeysEnabled)
        hotkeys = controller
    }

    private func setUpSettingsWiring() {
        settings.onChange = { [weak self] store in
            guard let self else { return }
            self.hotkeys?.apply(windowTiling: store.windowHotkeysEnabled,
                                utility: store.utilityHotkeysEnabled)
            self.engine?.stageTunables(store.effectiveTunables)
            self.powerApply(.setDisplayAwake(store.keepDisplayAwake))
            self.powerApply(.setFloor(store.batteryFloorPercent))
        }
    }

    // MARK: - Power (add-power-control)

    private func setUpPower() {
        powerPolicy = PowerPolicy(displayAwake: settings.keepDisplayAwake,
                                  floorPercent: settings.batteryFloorPercent)
        awake = AwakeController()
        let monitor = PowerSourceMonitor()
        monitor.onChange = { [weak self] status in self?.powerApply(.power(status)) }
        monitor.start()
        powerMonitor = monitor
        let gov = DisableSleepGovernor(adminRun: { try AdminShell.runPrivileged($0) })
        gov.reconcileAtLaunch()      // clear a stale SleepDisabled flag from a prior session
        governor = gov
    }

    /// Feed a command through the FSM and perform its effects, then reconcile the
    /// tick timer and the status glyph.
    func powerApply(_ command: PowerCommand) {
        for effect in powerPolicy.handle(command, now: Date()) { perform(effect) }
        refreshPowerTick()
        updateStatusGlyph()
    }

    private func perform(_ effect: PowerEffect) {
        switch effect {
        case let .acquire(spec):
            powerNotifier.requestAuthOnce()   // lazy, once, on first session start
            awake?.apply(spec)
        case let .release(reason):
            awake?.apply(nil)
            NSLog("Tiler: keep-awake released (%@)", reason.rawValue)
        case let .armClamshell(deadline):
            do {
                try governor?.arm(deadline: deadline)
            } catch {
                // Any arm failure (incl. a cancelled auth dialog) must not leave a
                // half-armed session: tear it back down through the FSM.
                NSLog("Tiler: clamshell arm failed: %@", "\(error)")
                powerApply(.clamshellArmFailed)
            }
        case .disarmClamshell:
            governor?.disarm()
        case let .notifyFloorStop(percent):
            powerNotifier.floorStop(percent: percent)
        }
    }

    /// A 5 s tick drives timed-session expiry; alive only while a session runs.
    private func refreshPowerTick() {
        if powerPolicy.isActive, powerTick == nil {
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + 5, repeating: 5)
            timer.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.powerApply(.tick) }
            }
            timer.resume()
            powerTick = timer
        } else if !powerPolicy.isActive, let timer = powerTick {
            timer.cancel()
            powerTick = nil
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
        case .left:
            command = action.thirdWidth
                ? .leftThird(nextDisplay: action.nextDisplay)
                : .leftHalf(nextDisplay: action.nextDisplay)
        case .right:
            command = action.thirdWidth
                ? .rightThird(nextDisplay: action.nextDisplay)
                : .rightHalf(nextDisplay: action.nextDisplay)
        case .up:
            command = action.thirdWidth ? .centerThird : .maximize
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
        menu.addItem(makeItem("Help", #selector(showGuideAction)))
        let settingsItem = makeItem("Settings", #selector(showSettingsAction))
        settingsItem.keyEquivalent = ","
        menu.addItem(settingsItem)
        settingsMenuItem = settingsItem
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

    /// Release tooling: renders the app's UI into PNGs for the README via SwiftUI
    /// ImageRenderer (no screen-recording permission, text rasterizes correctly,
    /// reproducible on every release). Window-chrome-less; a window-background
    /// wrapper keeps them looking like real screenshots.
    private func renderShots(to directory: String) {
        // Deterministic light appearance for the README regardless of system theme.
        NSApp.appearance = NSAppearance(named: .aqua)
        let dir = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        func write<V: View>(_ name: String, _ view: V) {
            let wrapped = view
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            let renderer = ImageRenderer(content: wrapped)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                NSLog("Tiler: render-shots failed for %@", name)
                return
            }
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
            NSLog("Tiler: render-shots wrote %@.png", name)
        }

        let guideModel = GuideModel(accessibilityGranted: true)
        write("guide", GuideView(model: guideModel))
        let settingsModel = SettingsModel(store: settings, accessibilityGranted: true)
        write("settings", SettingsView(model: settingsModel))
        // Power UI mockups (add-power-control gate 2.1) — need no live engine.
        write("power-menu", PowerMenuMockView())
        write("power-settings", PowerSettingsMockView())
        // Calibration preview needs the live gesture engine; skip it when there is no
        // trackpad (headless render still produces the window/power shots).
        if let engine {
            let calibrationModel = CalibrationModel(engine: engine) { _ in }
            write("calibration", CalibrationView(model: calibrationModel))
            calibrationModel.finish(apply: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
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
