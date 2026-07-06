import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Testing
import TilerCore
@testable import TilerSystem

/// AX-dependent system integration. Auto-skips unless the test host has the
/// Accessibility permission (USER GATE #1). The `.serialized` parent runs ALL
/// descendant tests one at a time — the hotkey E2E acts on the frontmost window,
/// so it must never overlap the window suite launching its own TextEdit windows.
@MainActor
@Suite(.enabled(if: AXIsProcessTrusted()), .serialized)
struct AXSystemTests {

    // Shared TextEdit target plumbing.
    struct TextEditTarget {
        let running: NSRunningApplication
        let axApp: AXUIElement
        let window: AXUIElement

        /// Terminate and wait — LaunchServices errors with procNotFound (-600) if the
        /// next open() races a dying TextEdit instance.
        func terminate() {
            running.forceTerminate()
            for _ in 0..<20 where !running.isTerminated {
                usleep(100_000)
            }
        }
    }

    // NB: retry uses try? instead of do/catch-in-loop — the latter crashes the
    // Swift 6.3.3 compiler here (IRGen archetype metadata, signal 11).
    @MainActor
    static func launchTextEdit(activate: Bool) async throws -> TextEditTarget {
        for attempt in 1...3 {
            if let t = try? await launchOnce(activate: activate) { return t }
            try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
        }
        Issue.record("TextEdit failed to launch after 3 attempts")
        throw CancellationError()
    }

    @MainActor
    private static func launchOnce(activate: Bool) async throws -> TextEditTarget {
        let doc = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiler-target-\(UUID().uuidString).txt")
        try "tiler integration target".write(to: doc, atomically: true, encoding: .utf8)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = activate
        config.createsNewApplicationInstance = true
        let running = try await NSWorkspace.shared.open(
            [doc],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
            configuration: config
        )
        let axApp = AXUIElementCreateApplication(running.processIdentifier)
        for _ in 0..<100 {
            if let window = focusedOrFirstWindow(of: axApp) {
                if activate { running.activate() }
                try? await Task.sleep(nanoseconds: 400_000_000)
                return TextEditTarget(running: running, axApp: axApp, window: window)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CancellationError()
    }

    private static func focusedOrFirstWindow(of axApp: AXUIElement) -> AXUIElement? {
        var raw: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &raw) == .success,
           let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() {
            return (raw as! AXUIElement)
        }
        var wins: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &wins) == .success,
              let wins, CFGetTypeID(wins) == CFArrayGetTypeID() else { return nil }
        let cfArray = wins as! CFArray
        guard CFArrayGetCount(cfArray) > 0, let ptr = CFArrayGetValueAtIndex(cfArray, 0) else { return nil }
        let element = Unmanaged<AXUIElement>.fromOpaque(ptr).takeUnretainedValue()
        return CFGetTypeID(element) == AXUIElementGetTypeID() ? element : nil
    }

    // Shared coordinate math (mirrors WindowActions).
    @MainActor static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    @MainActor
    static func axRect(fromCocoa rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    @MainActor
    static func visibleFrame(around axFrame: CGRect) -> CGRect {
        let cocoa = CGRect(x: axFrame.minX, y: primaryHeight - axFrame.maxY,
                           width: axFrame.width, height: axFrame.height)
        let screen = NSScreen.screens.max(by: { a, b in
            let ia = a.frame.intersection(cocoa), ib = b.frame.intersection(cocoa)
            return (ia.isNull ? 0 : ia.width * ia.height) < (ib.isNull ? 0 : ib.width * ib.height)
        }) ?? NSScreen.screens[0]
        return screen.visibleFrame
    }

    @MainActor
    static func expectClose(_ a: CGRect?, _ b: CGRect, tolerance: CGFloat = 2.0, _ label: String) {
        guard let a else {
            Issue.record("\(label): frame unreadable")
            return
        }
        #expect(abs(a.minX - b.minX) <= tolerance, "\(label): x \(a.minX) vs \(b.minX)")
        #expect(abs(a.minY - b.minY) <= tolerance, "\(label): y \(a.minY) vs \(b.minY)")
        #expect(abs(a.width - b.width) <= tolerance, "\(label): w \(a.width) vs \(b.width)")
        #expect(abs(a.height - b.height) <= tolerance, "\(label): h \(a.height) vs \(b.height)")
    }

    // MARK: - Window actions vs a real window (task 4.2)

    @MainActor
    @Suite("WindowActions AX integration")
    struct WindowActionsSuite {
        @Test func maximizeFillsVisibleFrame() async throws {
            let target = try await AXSystemTests.launchTextEdit(activate: false)
            defer { target.terminate() }
            let actions = WindowActions()
            actions.perform(.maximize, app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            let frame = actions.frame(of: target.window)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(
                fromCocoa: AXSystemTests.visibleFrame(around: frame ?? .zero)), "maximize")
        }

        @Test func leftAndRightHalves() async throws {
            let target = try await AXSystemTests.launchTextEdit(activate: false)
            defer { target.terminate() }
            let actions = WindowActions()

            actions.perform(.leftHalf(nextDisplay: false), app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            var frame = actions.frame(of: target.window)
            var vf = AXSystemTests.visibleFrame(around: frame ?? .zero)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(fromCocoa: CGRect(
                x: vf.minX, y: vf.minY, width: vf.width / 2, height: vf.height)), "leftHalf")

            actions.perform(.rightHalf(nextDisplay: false), app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            frame = actions.frame(of: target.window)
            vf = AXSystemTests.visibleFrame(around: frame ?? .zero)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(fromCocoa: CGRect(
                x: vf.minX + vf.width / 2, y: vf.minY, width: vf.width / 2, height: vf.height)), "rightHalf")
        }

        @Test func leftAndRightThirds() async throws {
            let target = try await AXSystemTests.launchTextEdit(activate: false)
            defer { target.terminate() }
            let actions = WindowActions()

            actions.perform(.leftThird(nextDisplay: false), app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            var frame = actions.frame(of: target.window)
            var vf = AXSystemTests.visibleFrame(around: frame ?? .zero)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(fromCocoa: CGRect(
                x: vf.minX, y: vf.minY, width: vf.width / 3, height: vf.height)), "leftThird")

            actions.perform(.rightThird(nextDisplay: false), app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            frame = actions.frame(of: target.window)
            vf = AXSystemTests.visibleFrame(around: frame ?? .zero)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(fromCocoa: CGRect(
                x: vf.minX + vf.width * 2 / 3, y: vf.minY, width: vf.width / 3, height: vf.height)), "rightThird")
        }

        @Test func centerThirdIsFullHeightCenteredThirdWidth() async throws {
            let target = try await AXSystemTests.launchTextEdit(activate: false)
            defer { target.terminate() }
            let actions = WindowActions()
            actions.perform(.centerThird, app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            let frame = actions.frame(of: target.window)
            let vf = AXSystemTests.visibleFrame(around: frame ?? .zero)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(fromCocoa: CGRect(
                x: vf.minX + vf.width / 3, y: vf.minY, width: vf.width / 3, height: vf.height)), "centerThird")
        }

        @Test func restoreReturnsPreTilerFrame() async throws {
            let target = try await AXSystemTests.launchTextEdit(activate: false)
            defer { target.terminate() }
            let actions = WindowActions()
            guard let original = actions.frame(of: target.window) else {
                Issue.record("original frame unreadable")
                return
            }
            actions.perform(.maximize, app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            actions.perform(.restore, app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            AXSystemTests.expectClose(actions.frame(of: target.window), original, "restore")
        }

        @Test func restoreWithoutHistoryIsANoop() async throws {
            let target = try await AXSystemTests.launchTextEdit(activate: false)
            defer { target.terminate() }
            let actions = WindowActions()
            guard let before = actions.frame(of: target.window) else {
                Issue.record("frame unreadable")
                return
            }
            actions.perform(.restore, app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            AXSystemTests.expectClose(actions.frame(of: target.window), before, "restore-noop")
        }

        // Single display: acts on the current screen. Two displays: exercises the
        // cross-display size→position→size path.
        @Test func nextDisplayLeftHalfLandsOnSomeScreenLeftHalf() async throws {
            let target = try await AXSystemTests.launchTextEdit(activate: false)
            defer { target.terminate() }
            let actions = WindowActions()
            actions.perform(.leftHalf(nextDisplay: true), app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(400))
            guard let frame = actions.frame(of: target.window) else {
                Issue.record("frame unreadable")
                return
            }
            let matches = NSScreen.screens.contains { screen in
                let vf = screen.visibleFrame
                let expected = AXSystemTests.axRect(fromCocoa: CGRect(
                    x: vf.minX, y: vf.minY, width: vf.width / 2, height: vf.height))
                return abs(frame.minX - expected.minX) <= 2 && abs(frame.width - expected.width) <= 2
                    && abs(frame.minY - expected.minY) <= 2 && abs(frame.height - expected.height) <= 2
            }
            #expect(matches, "no screen's left half matches \(frame)")
        }

        // Strict cross-display test (only meaningful with 2+ displays, esp. of
        // different sizes): after a next-display move the window must land FULLY on
        // the OTHER screen with THAT screen's exact half width — not a width carried
        // over from the source display (the reported bug).
        @Test(.enabled(if: NSScreen.screens.count >= 2))
        func nextDisplayMovesToOtherScreenWithCorrectWidth() async throws {
            let target = try await AXSystemTests.launchTextEdit(activate: false)
            defer { target.terminate() }
            let actions = WindowActions()

            // Anchor on the primary as left half, then push to the next display.
            actions.perform(.leftHalf(nextDisplay: false), app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(300))
            let startVF = AXSystemTests.visibleFrame(around: actions.frame(of: target.window) ?? .zero)

            actions.perform(.leftHalf(nextDisplay: true), app: target.axApp, window: target.window)
            try await Task.sleep(for: .milliseconds(400))
            guard let moved = actions.frame(of: target.window) else {
                Issue.record("frame unreadable"); return
            }
            let destVF = AXSystemTests.visibleFrame(around: moved)
            #expect(destVF != startVF, "window did not change displays: \(moved)")
            AXSystemTests.expectClose(moved, AXSystemTests.axRect(fromCocoa: CGRect(
                x: destVF.minX, y: destVF.minY, width: destVF.width / 2, height: destVF.height)),
                "next-display left half on destination screen")
        }
    }

    // MARK: - Hotkeys end-to-end (task 5.3)

    /// A real Tiler.app receives Ctrl+Shift+arrow key events posted via System Events
    /// (CGEventPost does NOT reach Carbon RegisterEventHotKey on this macOS) and must
    /// move the frontmost TextEdit window. Needs AX + Automation (osascript → System
    /// Events). Posts real global key events — don't type while this runs.
    @MainActor
    @Suite("Hotkey E2E")
    struct HotkeyE2ESuite {
        // Package root derived from this file's path (cwd is unreliable under
        // `swift test`): Tests/TilerIntegrationTests/AXSystemTests.swift → up 3.
        private static let tilerBinary: URL = {
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // TilerIntegrationTests
                .deletingLastPathComponent()   // Tests
                .deletingLastPathComponent()   // package root
                .appendingPathComponent("build/Tiler.app/Contents/MacOS/Tiler")
        }()

        private func launchTiler() throws -> Process {
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            kill.arguments = ["-f", "Tiler.app/Contents/MacOS/Tiler"]
            try? kill.run()
            kill.waitUntilExit()

            // Window hotkeys are OFF by default (split-hotkey-groups): enable them
            // for the instance under test, then restore the user's value — the
            // launched process has already read its settings by then.
            let domain = UserDefaults(suiteName: "pro.amilabs.tilerx")!
            let prior = domain.object(forKey: "windowHotkeysEnabled")
            domain.set(true, forKey: "windowHotkeysEnabled")

            let process = Process()
            process.executableURL = Self.tilerBinary
            try process.run()
            usleep(900_000)
            if let prior {
                domain.set(prior, forKey: "windowHotkeysEnabled")
            } else {
                domain.removeObject(forKey: "windowHotkeysEnabled")
            }
            return process
        }

        private func refocus(_ target: AXSystemTests.TextEditTarget) {
            target.running.activate()
            usleep(400_000)
        }

        private func mods(cmd: Bool) -> String {
            cmd ? "control down, shift down, command down" : "control down, shift down"
        }

        private func press(_ keyCode: Int, cmd: Bool = false) {
            runKeyScript(["key code \(keyCode) using {\(mods(cmd: cmd))}"])
        }

        /// Two presses inside ONE System Events session, both within the 300 ms
        /// window (a second osascript launch alone costs >300 ms).
        private func pressTwiceFast(_ keyCode: Int) {
            let line = "key code \(keyCode) using {\(mods(cmd: false))}"
            runKeyScript([line, "delay 0.05", line])
        }

        private func runKeyScript(_ statements: [String]) {
            let body = statements.joined(separator: "\n")
            let script = "tell application \"System Events\"\n\(body)\nend tell"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                Issue.record("osascript failed: \(error)")
            }
        }

        @Test func ctrlShiftLeftSnapsFrontmostWindowToLeftHalf() async throws {
            let tiler = try launchTiler()
            defer { tiler.terminate() }
            try await Task.sleep(nanoseconds: 1_500_000_000)
            let target = try await AXSystemTests.launchTextEdit(activate: true)
            defer { target.terminate() }

            refocus(target)
            press(kVK_LeftArrow)
            try await Task.sleep(nanoseconds: 1_000_000_000)

            let frame = WindowActions().frame(of: target.window)
            let vf = AXSystemTests.visibleFrame(around: frame ?? .zero)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(fromCocoa: CGRect(
                x: vf.minX, y: vf.minY, width: vf.width / 2, height: vf.height)), "e2e leftHalf")
        }

        @Test func singleUpPressMaximizesOnceAfterDisambiguationDelay() async throws {
            let tiler = try launchTiler()
            defer { tiler.terminate() }
            try await Task.sleep(nanoseconds: 1_500_000_000)
            let target = try await AXSystemTests.launchTextEdit(activate: true)
            defer { target.terminate() }
            let actions = WindowActions()
            let before = actions.frame(of: target.window)

            refocus(target)
            press(kVK_UpArrow)
            try await Task.sleep(nanoseconds: 120_000_000)
            AXSystemTests.expectClose(actions.frame(of: target.window), before ?? .zero, "no move inside window")
            try await Task.sleep(nanoseconds: 900_000_000)
            let frame = actions.frame(of: target.window)
            let vf = AXSystemTests.visibleFrame(around: frame ?? .zero)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(fromCocoa: vf), "e2e maximize")
        }

        @Test func doubleUpPressGivesCenterThirdAndNeverMaximizes() async throws {
            let tiler = try launchTiler()
            defer { tiler.terminate() }
            try await Task.sleep(nanoseconds: 1_500_000_000)
            let target = try await AXSystemTests.launchTextEdit(activate: true)
            defer { target.terminate() }

            refocus(target)
            pressTwiceFast(kVK_UpArrow)
            try await Task.sleep(nanoseconds: 1_200_000_000)

            let frame = WindowActions().frame(of: target.window)
            let vf = AXSystemTests.visibleFrame(around: frame ?? .zero)
            AXSystemTests.expectClose(frame, AXSystemTests.axRect(fromCocoa: CGRect(
                x: vf.minX + vf.width / 3, y: vf.minY, width: vf.width / 3, height: vf.height)),
                "e2e centerThird (double press must not maximize)")
        }

        @Test func restoreHotkeyReturnsPreTilerFrame() async throws {
            let tiler = try launchTiler()
            defer { tiler.terminate() }
            try await Task.sleep(nanoseconds: 1_500_000_000)
            let target = try await AXSystemTests.launchTextEdit(activate: true)
            defer { target.terminate() }
            let actions = WindowActions()
            let original = actions.frame(of: target.window)

            refocus(target)
            press(kVK_RightArrow)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            refocus(target)
            press(kVK_DownArrow)
            try await Task.sleep(nanoseconds: 1_000_000_000)

            AXSystemTests.expectClose(actions.frame(of: target.window), original ?? .zero, "e2e restore")
        }
    }
}
