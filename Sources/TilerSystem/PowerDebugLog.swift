import Foundation

/// Opt-in, low-overhead diagnostic log for power events (owner-driven multi-day runs).
/// Deliberately un-paranoid: only discrete EVENTS are written (no polling loop), one
/// concise line each, and the caller dedupes noisy sources. Bounded on disk — the file
/// rotates to a single `.1` backup past ~512 KB, so the footprint stays under ~1 MB.
/// Because writes happen only on real events, CPU cost is negligible.
///
/// Location: `~/Library/Logs/Tiler/power-debug.log`.
@MainActor public final class PowerDebugLog {
    public private(set) var isEnabled: Bool
    private let fileURL: URL
    private let maxBytes = 512 * 1024
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
        let backup = fileURL.deletingPathExtension().appendingPathExtension("1.log")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: fileURL, to: backup)
    }
}
