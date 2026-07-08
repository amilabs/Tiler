import AppKit
import Foundation

/// The clamshell lid-closed-awake root path (power spec, gate 0.3 decision). One admin
/// prompt per session arms `pmset -a disablesleep 1` plus a detached root **watchdog**
/// that restores `disablesleep 0` promptlessly once a sentinel file goes stale/absent
/// (normal stop, floor stop, crash, quit) or a timed deadline+grace passes. The app
/// keeps the sentinel fresh (every 10 s) while the session lives. This closes the
/// critical failure mode: a battery-floor auto-stop with the lid shut (Mac in a bag)
/// must not wait for a second auth dialog nobody can answer.
@MainActor public final class DisableSleepGovernor {
    public nonisolated static let sentinelPath = "/tmp/pro.amilabs.tilerx.clamshell.sentinel"

    private let adminRun: @Sendable (String) throws -> String
    private var refreshTimer: DispatchSourceTimer?

    public init(adminRun: @escaping @Sendable (String) throws -> String) {
        self.adminRun = adminRun
    }

    /// The exact privileged command: set the flag and detach the watchdog. `D` is an
    /// absolute epoch the watchdog compares against wall-clock — 0 for an indefinite
    /// session (never time-triggered), else the deadline plus a 120 s grace. `now` is
    /// accepted for call-site symmetry with `arm` and to keep this pure/testable; the
    /// epoch derives from `deadline`.
    public nonisolated static func armCommand(deadline: Date?, now: Date) -> String {
        let d = deadline.map { Int($0.timeIntervalSince1970) + 120 } ?? 0
        return [
            "pmset -a disablesleep 1",
            "nohup /bin/zsh -c 'S=\(sentinelPath); D=\(d)",
            "while :; do",
            "  [ -f \"$S\" ] || break",
            "  A=$(( $(date +%s) - $(stat -f %m \"$S\") )); [ \"$A\" -lt 45 ] || break",
            "  [ \"$D\" -eq 0 ] || [ \"$(date +%s)\" -lt \"$D\" ] || break",
            "  sleep 15",
            "done",
            "pmset -a disablesleep 0",
            "rm -f \"$S\"' >/dev/null 2>&1 &",
        ].joined(separator: "\n")
    }

    /// Write the sentinel, start the refresh timer, then arm via admin auth. On any
    /// failure (incl. a cancelled dialog) undo the sentinel/timer and rethrow so the
    /// caller can tear the half-started session down (never run half-armed).
    public func arm(deadline: Date?) throws {
        FileManager.default.createFile(atPath: Self.sentinelPath, contents: Data())
        startRefreshTimer()
        do {
            _ = try adminRun(Self.armCommand(deadline: deadline, now: Date()))
            NSLog("Tiler: clamshell armed (disablesleep 1 + watchdog)")
        } catch {
            stopRefreshTimer()
            try? FileManager.default.removeItem(atPath: Self.sentinelPath)
            throw error
        }
    }

    /// Stop refreshing and drop the sentinel; the watchdog restores `disablesleep 0`
    /// within its poll grace (~15 s), promptlessly.
    public func disarm() {
        stopRefreshTimer()
        try? FileManager.default.removeItem(atPath: Self.sentinelPath)
        NSLog("Tiler: clamshell disarmed (sentinel removed; watchdog will restore)")
    }

    /// `SleepDisabled 1` with no live sentinel means a previous session left the flag
    /// set (e.g. a reboot before the watchdog cleared it). Offer a one-click restore.
    /// Returns whether a stale flag was detected.
    @discardableResult
    public func reconcileAtLaunch() -> Bool {
        guard Self.sleepDisabledNow(),
              !FileManager.default.fileExists(atPath: Self.sentinelPath) else { return false }
        NSLog("Tiler: stale SleepDisabled flag detected at launch")
        let alert = NSAlert()
        alert.messageText = "Sleep is still disabled"
        alert.informativeText = "Tiler left sleep disabled from a previous lid-closed session. "
            + "Restore normal sleep behavior?"
        alert.addButton(withTitle: "Restore normal sleep")
        alert.addButton(withTitle: "Keep as is")
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                _ = try adminRun("pmset -a disablesleep 0")
                NSLog("Tiler: stale flag cleared")
            } catch {
                NSLog("Tiler: stale-flag restore failed/cancelled: %@", "\(error)")
            }
        } else {
            NSLog("Tiler: stale flag kept by user choice")
        }
        return true
    }

    /// `pmset -g` reports `SleepDisabled 1` only once the flag has been touched; macOS
    /// omits the key otherwise, so an absent key reads as false.
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
