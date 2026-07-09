import AppKit
import Foundation

/// The clamshell lid-closed path (power spec). Sets/clears `pmset -a disablesleep`
/// through the standard admin dialog — a FOREGROUND `osascript … with administrator
/// privileges` command, which reliably runs as root. (The earlier detached background
/// watchdog was silently reaped by the privileged wrapper and never restored the flag —
/// proven on the owner's machine — so `do shell script … &` cannot host a persistent
/// root process.)
///
/// Restore happens when the app ends the session (`disarm`), backstopped by a
/// self-check at launch and on wake (`promptRestore`): a leftover flag with no live
/// clamshell session is offered for a one-click restore. macOS caches the admin
/// credential for ~5 min, so a short arm→disarm cycle needs only the one prompt.
@MainActor public final class DisableSleepGovernor {
    private let adminRun: @Sendable (String) throws -> String

    public init(adminRun: @escaping @Sendable (String) throws -> String) {
        self.adminRun = adminRun
    }

    /// One admin prompt sets the flag (foreground → runs as root). Throws on cancel.
    public func arm() throws {
        _ = try adminRun("pmset -a disablesleep 1")
        NSLog("Tiler: clamshell armed (disablesleep 1)")
    }

    /// Restore normal sleep. Prompts for admin unless the credential is still cached
    /// (~5 min) from arming. Throws on cancel/failure (the flag then persists until the
    /// next self-check).
    public func disarm() throws {
        _ = try adminRun("pmset -a disablesleep 0")
        NSLog("Tiler: clamshell disarmed (disablesleep 0)")
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

    /// Offer a one-click restore of a leftover flag (alert → foreground admin restore).
    /// The caller decides WHEN to call this (launch / wake, only when no live clamshell
    /// session holds the flag legitimately). Returns true iff the flag was cleared.
    @discardableResult
    public func promptRestore() -> Bool {
        NSLog("Tiler: leftover SleepDisabled flag detected")
        let alert = NSAlert()
        alert.messageText = "Sleep is still disabled"
        alert.informativeText = "Tiler left sleep disabled from a lid-closed session. "
            + "Restore normal sleep behavior?"
        alert.addButton(withTitle: "Restore normal sleep")
        alert.addButton(withTitle: "Keep as is")
        guard alert.runModal() == .alertFirstButtonReturn else {
            NSLog("Tiler: leftover flag kept by user choice")
            return false
        }
        do {
            try disarm()
            return true
        } catch {
            NSLog("Tiler: leftover-flag restore failed/cancelled: %@", "\(error)")
            return false
        }
    }
}
