import AppKit
import ApplicationServices
import Testing
import TilerCore
@testable import TilerSystem

/// Real-window AX integration (task 4.2). Auto-skips unless the test host process
/// has the Accessibility permission (USER GATE #1) — grant it to the terminal/host
/// running `swift test`, then these run for real against TextEdit.
@MainActor
@Suite("WindowActions AX integration", .enabled(if: AXIsProcessTrusted()), .serialized)
struct WindowActionsIntegrationTests {

    // MARK: - Target app plumbing

    struct Target {
        let running: NSRunningApplication
        let axApp: AXUIElement
        let window: AXUIElement

        func terminate() {
            running.forceTerminate()
        }
    }

    private func launchTarget() async throws -> Target {
        let doc = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiler-target-\(UUID().uuidString).txt")
        try "tiler integration target".write(to: doc, atomically: true, encoding: .utf8)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        let running = try await NSWorkspace.shared.open(
            [doc],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
            configuration: config
        )
        let axApp = AXUIElementCreateApplication(running.processIdentifier)
        for _ in 0..<100 {
            if let window = windows(of: axApp).first {
                return Target(running: running, axApp: axApp, window: window)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("TextEdit window did not appear within 10 s")
        throw CancellationError()
    }

    private func windows(of axApp: AXUIElement) -> [AXUIElement] {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == CFArrayGetTypeID() else { return [] }
        let cfArray = raw as! CFArray
        return (0..<CFArrayGetCount(cfArray)).compactMap { i in
            guard let ptr = CFArrayGetValueAtIndex(cfArray, i) else { return nil }
            let element = Unmanaged<AXUIElement>.fromOpaque(ptr).takeUnretainedValue()
            return CFGetTypeID(element) == AXUIElementGetTypeID() ? element : nil
        }
    }

    // MARK: - Geometry helpers (mirror of the implementation's coordinate math)

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    private func axRect(fromCocoa rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private func screenOf(_ axFrame: CGRect) -> NSScreen {
        let cocoa = CGRect(x: axFrame.minX, y: primaryHeight - axFrame.maxY,
                           width: axFrame.width, height: axFrame.height)
        return NSScreen.screens.max(by: { a, b in
            areaOf(a.frame.intersection(cocoa)) < areaOf(b.frame.intersection(cocoa))
        }) ?? NSScreen.screens[0]
    }

    private func areaOf(_ r: CGRect) -> CGFloat { r.isNull ? 0 : r.width * r.height }

    private func expectClose(_ a: CGRect?, _ b: CGRect, tolerance: CGFloat = 2.0,
                             _ label: String) {
        guard let a else {
            Issue.record("\(label): frame unreadable")
            return
        }
        #expect(abs(a.minX - b.minX) <= tolerance, "\(label): x \(a.minX) vs \(b.minX)")
        #expect(abs(a.minY - b.minY) <= tolerance, "\(label): y \(a.minY) vs \(b.minY)")
        #expect(abs(a.width - b.width) <= tolerance, "\(label): w \(a.width) vs \(b.width)")
        #expect(abs(a.height - b.height) <= tolerance, "\(label): h \(a.height) vs \(b.height)")
    }

    // MARK: - Tests

    @Test func maximizeFillsVisibleFrame() async throws {
        let target = try await launchTarget()
        defer { target.terminate() }
        let actions = WindowActions()
        actions.perform(.maximize, app: target.axApp, window: target.window)
        try await Task.sleep(for: .milliseconds(300))
        let frame = actions.frame(of: target.window)
        let vf = screenOf(frame ?? .zero).visibleFrame
        expectClose(frame, axRect(fromCocoa: vf), "maximize")
    }

    @Test func leftAndRightHalves() async throws {
        let target = try await launchTarget()
        defer { target.terminate() }
        let actions = WindowActions()

        actions.perform(.leftHalf(nextDisplay: false), app: target.axApp, window: target.window)
        try await Task.sleep(for: .milliseconds(300))
        var frame = actions.frame(of: target.window)
        var vf = screenOf(frame ?? .zero).visibleFrame
        expectClose(frame, axRect(fromCocoa: CGRect(
            x: vf.minX, y: vf.minY, width: vf.width / 2, height: vf.height)), "leftHalf")

        actions.perform(.rightHalf(nextDisplay: false), app: target.axApp, window: target.window)
        try await Task.sleep(for: .milliseconds(300))
        frame = actions.frame(of: target.window)
        vf = screenOf(frame ?? .zero).visibleFrame
        expectClose(frame, axRect(fromCocoa: CGRect(
            x: vf.minX + vf.width / 2, y: vf.minY, width: vf.width / 2, height: vf.height)), "rightHalf")
    }

    @Test func centerThirdIsFullHeightCenteredThirdWidth() async throws {
        let target = try await launchTarget()
        defer { target.terminate() }
        let actions = WindowActions()
        actions.perform(.centerThird, app: target.axApp, window: target.window)
        try await Task.sleep(for: .milliseconds(300))
        let frame = actions.frame(of: target.window)
        let vf = screenOf(frame ?? .zero).visibleFrame
        expectClose(frame, axRect(fromCocoa: CGRect(
            x: vf.minX + vf.width / 3, y: vf.minY, width: vf.width / 3, height: vf.height)), "centerThird")
    }

    @Test func restoreReturnsPreTilerFrame() async throws {
        let target = try await launchTarget()
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
        expectClose(actions.frame(of: target.window), original, "restore")
    }

    @Test func restoreWithoutHistoryIsANoop() async throws {
        let target = try await launchTarget()
        defer { target.terminate() }
        let actions = WindowActions()
        guard let before = actions.frame(of: target.window) else {
            Issue.record("frame unreadable")
            return
        }
        actions.perform(.restore, app: target.axApp, window: target.window)
        try await Task.sleep(for: .milliseconds(300))
        expectClose(actions.frame(of: target.window), before, "restore-noop")
    }

    // With a single display, next-display variants act on the current screen.
    // With two, this genuinely exercises the cross-display size→position→size path.
    @Test func nextDisplayLeftHalfLandsOnSomeScreenLeftHalf() async throws {
        let target = try await launchTarget()
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
            let expected = axRect(fromCocoa: CGRect(
                x: vf.minX, y: vf.minY, width: vf.width / 2, height: vf.height))
            return abs(frame.minX - expected.minX) <= 2 && abs(frame.width - expected.width) <= 2
                && abs(frame.minY - expected.minY) <= 2 && abs(frame.height - expected.height) <= 2
        }
        #expect(matches, "no screen's left half matches \(frame)")
    }
}
