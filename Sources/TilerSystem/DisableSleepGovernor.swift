import AppKit
import Foundation

/// The clamshell lid-closed path (power spec). One admin prompt at start sets
/// `pmset -a disablesleep 1` AND runs an inline watchdog that clears it again — all as
/// the FOREGROUND command of a single `osascript … with administrator privileges`,
/// launched asynchronously. (Crucially NOT a backgrounded `&` child: the privileged
/// wrapper reaps those, so the earlier watchdog never restored the flag — proven on the
/// owner's machine 2026-07-09. A foreground command runs as root, survives the app's
/// death, and restores WITHOUT a second prompt.)
///
/// The app keeps a sentinel file fresh (~10 s) while the session lives; the watchdog
/// restores the flag once the sentinel is removed (clean stop / expiry / floor), goes
/// stale (crash / quit / in a bag), or a timed deadline+grace passes. A launch/wake
/// self-check (`sleepDisabledNow` + `restoreNow`) is the rare backstop if the watchdog
/// process is itself killed.
@MainActor public final class DisableSleepGovernor {
    /// The app (non-root) creates/refreshes/removes the sentinel, so it lives in /tmp
    /// where the app owns it. The "started" marker is written by the ROOT watchdog, so
    /// it goes in the per-user temp dir (non-sticky, app-owned) — otherwise a
    /// root-owned marker in sticky /tmp could never be cleared by the app, breaking the
    /// next start's cancel detection.
    public nonisolated static let sentinelPath = "/tmp/pro.amilabs.tilerx.clamshell.sentinel"
    public nonisolated static let startedPath = NSTemporaryDirectory() + "pro.amilabs.tilerx.clamshell.started"

    private let adminRun: @Sendable (String) throws -> String
    private var refreshTimer: DispatchSourceTimer?
    private var armProcess: Process?

    public init(adminRun: @escaping @Sendable (String) throws -> String) {
        self.adminRun = adminRun
    }

    /// The privileged foreground command: set the flag, mark "started", poll the
    /// sentinel, then restore. `D` is an absolute epoch (deadline + 120 s grace) or 0
    /// for indefinite. Exact bytes are locked by tests.
    public nonisolated static func armCommand(deadline: Date?) -> String {
        let d = deadline.map { Int($0.timeIntervalSince1970) + 120 } ?? 0
        return [
            "pmset -a disablesleep 1",
            "echo 1 > \(startedPath)",
            "S=\(sentinelPath); D=\(d)",
            "while [ -f \"$S\" ]; do",
            "  A=$(( $(date +%s) - $(stat -f %m \"$S\") )); [ \"$A\" -lt 45 ] || break",
            "  [ \"$D\" -eq 0 ] || [ \"$(date +%s)\" -lt \"$D\" ] || break",
            "  sleep 10",
            "done",
            "pmset -a disablesleep 0",
            "rm -f \"$S\"",
        ].joined(separator: "\n")
    }

    /// Launch the arm+watchdog asynchronously (one admin prompt). Writes the sentinel
    /// and starts refreshing it. If the osascript exits WITHOUT the "started" marker the
    /// prompt was cancelled/failed → undo and call `onArmFailed` (so the FSM tears the
    /// half-started session down).
    public func arm(deadline: Date?, onArmFailed: @escaping @MainActor () -> Void) {
        FileManager.default.createFile(atPath: Self.sentinelPath, contents: Data())
        try? FileManager.default.removeItem(atPath: Self.startedPath)
        let script = "do shell script \(AdminShell.appleScriptLiteral(Self.armCommand(deadline: deadline)))"
            + " with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.terminationHandler = { [weak self] _ in
            let armed = FileManager.default.fileExists(atPath: Self.startedPath)
            Task { @MainActor in
                guard let self else { return }
                self.stopRefreshTimer()
                try? FileManager.default.removeItem(atPath: Self.startedPath)
                self.armProcess = nil
                if armed {
                    NSLog("Tiler: clamshell watchdog exited (flag restored)")
                } else {
                    try? FileManager.default.removeItem(atPath: Self.sentinelPath)
                    NSLog("Tiler: clamshell arm cancelled/failed")
                    onArmFailed()
                }
            }
        }
        do {
            try process.run()
            armProcess = process
            startRefreshTimer()
            NSLog("Tiler: clamshell arming (foreground watchdog, async)")
        } catch {
            try? FileManager.default.removeItem(atPath: Self.sentinelPath)
            NSLog("Tiler: clamshell arm launch failed: %@", "\(error)")
            onArmFailed()
        }
    }

    /// End the session: stop refreshing and drop the sentinel — the watchdog restores
    /// `disablesleep 0` promptlessly (no second admin prompt).
    public func disarm() {
        stopRefreshTimer()
        try? FileManager.default.removeItem(atPath: Self.sentinelPath)
        NSLog("Tiler: clamshell disarm (watchdog will restore promptlessly)")
    }

    /// Direct restore for the launch/wake backstop (foreground admin — prompts). Used
    /// only when a leftover flag exists with no live watchdog.
    public func restoreNow() throws {
        _ = try adminRun("pmset -a disablesleep 0")
        try? FileManager.default.removeItem(atPath: Self.sentinelPath)
    }

    public nonisolated static func sleepDisabledNow() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do { try process.run() } catch { return false }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        return text.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler {
            MainActor.assumeIsolated {
                try? FileManager.default.setAttributes([.modificationDate: Date()],
                                                       ofItemAtPath: Self.sentinelPath)
            }
        }
        timer.resume()
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }
}
