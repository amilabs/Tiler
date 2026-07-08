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
    private var powerProfile: PowerProfileController?
    /// Lid-closed opt-in for the NEXT start; resets to false after every start
    /// (deliberate per-session friction).
    private var pendingClamshell = false
    private weak var powerHeaderItem: NSMenuItem?
    private weak var powerStopItem: NSMenuItem?
    private weak var powerClamshellItem: NSMenuItem?
    private weak var powerTopItem: NSMenuItem?         // prominent active-state row at the menu top
    private weak var powerTopSeparator: NSMenuItem?
    private var menuTick: DispatchSourceTimer?          // live countdown, only while the menu is open
    // Status indicator is re-rendered only when the active state or appearance changes.
    private var lastIndicatorActive: Bool?
    private var lastIndicatorAppearance: NSAppearance.Name?
    private var powerLog: PowerDebugLog?
    private var lastLoggedPower: String?
    private var lastOnBattery = false

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
                : (powerPolicy.isActive ? "Tiler: Prevent Sleep active" : "Tiler"))
        // Settings item carries the permission alert (stabilize-menu spec).
        settingsMenuItem?.title = trusted ? "Settings" : "Settings ⚠︎"
        updateSessionIndicator()
    }

    /// Swap the status glyph for the active-session badge (gate 2.1 pick). Only
    /// re-renders when the active state or the menu-bar appearance changes.
    private func updateSessionIndicator() {
        guard let button = statusItem?.button else { return }
        let active = powerPolicy.isActive
        let appearance = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua
        guard active != lastIndicatorActive || appearance != lastIndicatorAppearance else { return }
        button.image = active ? sessionIndicatorImage(dark: appearance == .darkAqua) : plainHandImage()
        lastIndicatorActive = active
        lastIndicatorAppearance = appearance
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshConflictAlert()
        refreshPowerMenu()
        startMenuTick()
    }

    func menuDidClose(_ menu: NSMenu) {
        stopMenuTick()
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
        powerLog = PowerDebugLog(enabled: settings.powerDebugLogging)
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

        let profile = PowerProfileController(store: settings,
                                             adminRun: { try AdminShell.runPrivileged($0) })
        let deepSleepActive = profile.isDeepSleepActive()
        settings.deepSleepOnBattery = deepSleepActive               // reality wins over stored intent
        powerProfile = profile

        let power = PowerSourceMonitor.read()
        lastOnBattery = power.onBattery
        plog("launch — deepSleep=\(deepSleepActive) power=\(power.percent.map(String.init) ?? "-")% "
             + "\(power.onBattery ? "battery" : "AC") floor=\(settings.batteryFloorPercent)")
    }

    /// Deep Sleep toggle handler (from SettingsModel.onDeepSleepToggle). On a
    /// cancelled/failed authorization, re-read the real state and revert the toggle.
    private func applyDeepSleep(_ wanted: Bool) {
        guard let profile = powerProfile else { return }
        do {
            if wanted { try profile.enable() } else { try profile.disable() }
            plog("deepSleep \(wanted ? "enabled" : "disabled")")
        } catch {
            plog("deepSleep toggle failed/cancelled: \(error)")
            settingsModel?.reflectDeepSleep(profile.isDeepSleepActive())
        }
    }

    /// NSLog (ephemeral) + the opt-in debug file (owner's multi-day diagnostics).
    private func plog(_ line: String) {
        NSLog("Tiler: %@", line)
        powerLog?.log(line)
    }

    /// Feed a command through the FSM and perform its effects, then reconcile the
    /// tick timer and the status glyph.
    func powerApply(_ command: PowerCommand) {
        logCommand(command)
        for effect in powerPolicy.handle(command, now: Date()) { perform(effect) }
        refreshPowerTick()
        updateStatusGlyph()
    }

    /// Concise, deduped event lines for the debug log (ticks are never logged; power
    /// readings only on a source flip or, while a session runs, a changed value).
    private func logCommand(_ command: PowerCommand) {
        switch command {
        case let .start(clamshell, duration):
            let d = duration.map { "\(Int($0 / 60))m" } ?? "indefinite"
            plog("start clamshell=\(clamshell) duration=\(d) floor=\(settings.batteryFloorPercent) display=\(settings.keepDisplayAwake)")
        case .stop:
            plog("stop (user)")
        case let .power(status):
            let key = "\(status.percent.map(String.init) ?? "-")% \(status.onBattery ? "battery" : "AC")"
            let flipped = status.onBattery != lastOnBattery
            lastOnBattery = status.onBattery
            if flipped || (powerPolicy.isActive && key != lastLoggedPower) {
                lastLoggedPower = key
                plog("power \(key)")
            }
        case let .setDisplayAwake(value): plog("setDisplayAwake=\(value)")
        case let .setFloor(value): plog("setFloor=\(value)")
        case .clamshellArmFailed: plog("clamshellArmFailed")
        case .tick: break                 // never logged (noise)
        }
    }

    private func perform(_ effect: PowerEffect) {
        switch effect {
        case let .acquire(spec):
            powerNotifier.requestAuthOnce()   // lazy, once, on first session start
            awake?.apply(spec)
            plog("acquire display=\(spec.displayAwake) system=\(spec.systemSleepBlock)")
        case let .release(reason):
            awake?.apply(nil)
            plog("release \(reason.rawValue)")
        case let .armClamshell(deadline):
            plog("clamshell arm deadline=\(deadline.map { ISO8601DateFormatter().string(from: $0) } ?? "none")")
            do {
                try governor?.arm(deadline: deadline)
            } catch {
                // Any arm failure (incl. a cancelled auth dialog) must not leave a
                // half-armed session: tear it back down through the FSM.
                plog("clamshell arm FAILED: \(error)")
                powerApply(.clamshellArmFailed)
            }
        case .disarmClamshell:
            governor?.disarm()
            plog("clamshell disarm")
        case let .notifyFloorStop(percent):
            powerNotifier.floorStop(percent: percent)
            plog("floorStop \(percent)%")
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

    // MARK: Prevent Sleep menu actions

    @objc private func powerStartIndefinite() {
        powerApply(.start(clamshell: pendingClamshell, duration: nil))
        pendingClamshell = false
    }

    @objc private func powerStartDuration(_ sender: NSMenuItem) {
        powerApply(.start(clamshell: pendingClamshell, duration: TimeInterval(sender.tag) * 60))
        pendingClamshell = false
    }

    @objc private func powerStopAction() {
        powerApply(.stop)
    }

    @objc private func toggleClamshell(_ sender: NSMenuItem) {
        pendingClamshell.toggle()
        sender.state = pendingClamshell ? .on : .off
    }

    /// Refresh the top indicator, submenu header, Stop, and checkbox from the FSM
    /// (called on menu open and, for a timed session, every second while open).
    private func refreshPowerMenu() {
        let active = powerPolicy.isActive
        let state = powerStateText(now: Date())
        powerHeaderItem?.title = active ? "On — \(state)" : "Off"
        powerStopItem?.isEnabled = active
        powerClamshellItem?.state = pendingClamshell ? .on : .off

        powerTopItem?.isHidden = !active
        powerTopSeparator?.isHidden = !active
        if active {
            powerTopItem?.attributedTitle = boldMenuTitle("Prevent Sleep — \(state)")
        }
    }

    /// "27 min left · lid-closed ⚠" / "until stopped" etc.
    private func powerStateText(now: Date) -> String {
        guard powerPolicy.isActive else { return "Off" }
        let lid = powerPolicy.clamshell ? " · lid-closed ⚠" : ""
        if let remaining = powerPolicy.remaining(now: now) {
            return "\(formatRemaining(remaining)) left\(lid)"
        }
        return "until stopped\(lid)"
    }

    private func boldMenuTitle(_ s: String) -> NSAttributedString {
        NSAttributedString(string: s, attributes: [
            .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize),
        ])
    }

    /// Live countdown while the menu is open (timed sessions only); stopped on close.
    private func startMenuTick() {
        stopMenuTick()
        guard powerPolicy.isActive, powerPolicy.deadline != nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.refreshPowerMenu() } }
        timer.resume()
        menuTick = timer
    }

    private func stopMenuTick() {
        menuTick?.cancel()
        menuTick = nil
    }

    /// "27 min" under 2 h; "2 h 5 min" (or "3 h") from 2 h up.
    private func formatRemaining(_ t: TimeInterval) -> String {
        let minutes = max(0, Int((t / 60).rounded(.up)))
        guard minutes >= 120 else { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
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
        item.button?.image = plainHandImage()
        item.button?.imagePosition = .imageLeft

        let menu = NSMenu()
        menu.autoenablesItems = false     // we manage the top indicator + Stop enabled state

        // Prominent active-state row at the very top (hidden while inactive). Bold, with
        // the red cup mark and a live countdown; refreshed in menuWillOpen / while open.
        let topItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        topItem.isHidden = true
        let cupConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            .applying(.init(paletteColors: [.systemRed]))
        topItem.image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(cupConfig)
        menu.addItem(topItem)
        powerTopItem = topItem
        let topSeparator = NSMenuItem.separator()
        topSeparator.isHidden = true
        menu.addItem(topSeparator)
        powerTopSeparator = topSeparator

        menu.addItem(makeItem("Help", #selector(showGuideAction)))
        let settingsItem = makeItem("Settings", #selector(showSettingsAction))
        settingsItem.keyEquivalent = ","
        menu.addItem(settingsItem)
        settingsMenuItem = settingsItem
        menu.addItem(.separator())
        menu.addItem(makePreventSleepMenu())   // power section, between primaries and Quit
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

    /// "Prevent Sleep" submenu (power / app-shell spec). Header + Stop + clamshell
    /// checkbox refresh in `menuWillOpen`.
    private func makePreventSleepMenu() -> NSMenuItem {
        let submenu = NSMenu()
        submenu.autoenablesItems = false       // Stop is enabled by session state, not target

        let header = NSMenuItem(title: "Off", action: nil, keyEquivalent: "")
        header.isEnabled = false
        submenu.addItem(header)
        powerHeaderItem = header
        submenu.addItem(.separator())

        submenu.addItem(makeItem("On (until stopped)", #selector(powerStartIndefinite)))
        let durations: [(String, Int)] = [
            ("For 10 minutes", 10), ("For 30 minutes", 30), ("For 1 hour", 60),
            ("For 2 hours", 120), ("For 5 hours", 300), ("For 10 hours", 600),
            ("For 24 hours", 1440),
        ]
        for (title, minutes) in durations {
            let dur = makeItem(title, #selector(powerStartDuration(_:)))
            dur.tag = minutes
            submenu.addItem(dur)
        }
        submenu.addItem(.separator())

        let clamshell = makeItem("Prevent sleep with lid closed ⚠", #selector(toggleClamshell(_:)))
        submenu.addItem(clamshell)
        powerClamshellItem = clamshell
        submenu.addItem(.separator())

        let stop = makeItem("Stop", #selector(powerStopAction))
        stop.isEnabled = false
        submenu.addItem(stop)
        powerStopItem = stop

        let root = NSMenuItem(title: "Prevent Sleep", action: nil, keyEquivalent: "")
        root.submenu = submenu
        return root
    }

    /// The plain, template menu-bar glyph (adapts to light/dark automatically).
    private func plainHandImage() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: "hand.pinch.fill",
                            accessibilityDescription: "Tiler")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    /// Active-session glyph (gate 2.1 pick): the hand with a solid red disc + white
    /// cup silhouette badge at its bottom-right. Non-template, so rendered for the
    /// current appearance.
    private func sessionIndicatorImage(dark: Bool) -> NSImage? {
        let hand: Color = dark ? .white : .black
        let badge = ZStack {
            Circle().fill(Color(nsColor: .systemRed)).frame(width: 12, height: 12)
            Image(systemName: "cup.and.saucer.fill").font(.system(size: 7)).foregroundStyle(.white)
        }
        let view = ZStack {
            Image(systemName: "hand.pinch.fill").font(.system(size: 15)).foregroundStyle(hand)
            badge.offset(x: 5, y: 5)
        }
        .frame(width: 22, height: 20)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = renderer.nsImage
        image?.isTemplate = false
        return image
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
        write("power-indicator", PowerIndicatorMockView())
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
            settingsModel?.onDeepSleepToggle = { [weak self] wanted in
                self?.applyDeepSleep(wanted)
            }
            settingsModel?.onDebugLoggingToggle = { [weak self] on in
                self?.powerLog?.setEnabled(on)
            }
            settingsModel?.onRevealDebugLog = { [weak self] in
                guard let url = self?.powerLog?.url else { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
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
