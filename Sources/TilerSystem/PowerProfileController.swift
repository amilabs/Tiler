import Foundation
import TilerCore

/// The persistent battery-side Deep Sleep profile (power spec). Switches battery sleep
/// to full hibernation (`hibernatemode 25`, Power Nap / TCP keep-alive off, proximity
/// wake off where present) via admin-authorized `pmset -b`. Snapshots the previous
/// values before the first write and restores them verbatim on disable (empty snapshot
/// → Apple portable defaults). AC-side sleep is never touched. At launch the toggle is
/// reconciled with actual `pmset -g custom` (reality wins over stored intent).
@MainActor public final class PowerProfileController {
    private let store: SettingsStore
    private let adminRun: @Sendable (String) throws -> String

    public init(store: SettingsStore, adminRun: @escaping @Sendable (String) throws -> String) {
        self.store = store
        self.adminRun = adminRun
    }

    /// Keys the profile overwrites (and therefore snapshots), in restore order.
    private nonisolated static let touchedKeys = ["hibernatemode", "powernap", "tcpkeepalive", "proximitywake"]

    public func isDeepSleepActive() -> Bool {
        PmsetCustomParser.batterySettings(from: readCustom())["hibernatemode"] == "25"
    }

    /// Snapshot current battery values, then apply the hibernate profile. Snapshot is
    /// persisted only after a successful (authorized) write.
    public func enable() throws {
        let current = PmsetCustomParser.batterySettings(from: readCustom())
        var snapshot: [String: String] = [:]
        for key in Self.touchedKeys where current[key] != nil {
            snapshot[key] = current[key]
        }
        _ = try adminRun(Self.applyCommand(current: current))
        store.powerSnapshot = snapshot
    }

    /// Restore the snapshotted values verbatim (or portable defaults), then clear it.
    public func disable() throws {
        _ = try adminRun(Self.restoreCommand(snapshot: store.powerSnapshot ?? [:]))
        store.powerSnapshot = nil
    }

    /// `pmset -b hibernatemode 25 powernap 0 tcpkeepalive 0`, plus ` proximitywake 0`
    /// only when the current profile has that key.
    public nonisolated static func applyCommand(current: [String: String]) -> String {
        var command = "pmset -b hibernatemode 25 powernap 0 tcpkeepalive 0"
        if current["proximitywake"] != nil { command += " proximitywake 0" }
        return command
    }

    /// Restore the snapshotted keys we touched, in a fixed order. An empty snapshot
    /// falls back to Apple's portable defaults.
    public nonisolated static func restoreCommand(snapshot: [String: String]) -> String {
        guard !snapshot.isEmpty else {
            return "pmset -b hibernatemode 3 powernap 1 tcpkeepalive 1"
        }
        var parts = ["pmset -b"]
        for key in touchedKeys {
            if let value = snapshot[key] { parts.append("\(key) \(value)") }
        }
        return parts.joined(separator: " ")
    }

    private func readCustom() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "custom"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do { try process.run() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
