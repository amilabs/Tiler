import Foundation

/// Opt-in diagnostic log for power events (owner-driven multi-day runs). Records
/// discrete events plus a ~15 s liveness heartbeat while a session runs (so a sleep
/// gap is visible). Bounded on disk: rotates through 3 backups past ~5 MB each, so the
/// footprint stays under ~20 MB — plenty of headroom to leave on for days.
///
/// Location: `~/Library/Logs/Tiler/power-debug.log` (+ `.1`/`.2`/`.3` backups).
@MainActor public final class PowerDebugLog {
    public private(set) var isEnabled: Bool
    private let fileURL: URL
    private let maxBytes = 5 * 1024 * 1024
    private let backups = 3
    private let stamp: ISO8601DateFormatter

    public init(enabled: Bool) {
        isEnabled = enabled
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Tiler", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("power-debug.log")
        stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withInternetDateTime]
    }

    public var url: URL { fileURL }

    /// Toggle logging; the transition itself is always recorded so runs are delimited.
    public func setEnabled(_ on: Bool) {
        guard on != isEnabled else { return }
        if on { isEnabled = true; write("logging enabled") }
        else { write("logging disabled"); isEnabled = false }
    }

    public func log(_ line: String) {
        guard isEnabled else { return }
        write(line)
    }

    private func write(_ line: String) {
        rotateIfNeeded()
        let text = "\(stamp.string(from: Date())) \(line)\n"
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)   // first write / file absent
        }
    }

    private func rotateIfNeeded() {
        guard let size = (try? FileManager.default
            .attributesOfItem(atPath: fileURL.path)[.size]) as? Int, size > maxBytes else { return }
        let fm = FileManager.default
        let base = fileURL.deletingPathExtension()   // …/power-debug
        func backup(_ n: Int) -> URL { base.appendingPathExtension("\(n).log") }
        try? fm.removeItem(at: backup(backups))       // drop the oldest
        for n in stride(from: backups - 1, through: 1, by: -1) {
            try? fm.moveItem(at: backup(n), to: backup(n + 1))
        }
        try? fm.moveItem(at: fileURL, to: backup(1))
    }
}
