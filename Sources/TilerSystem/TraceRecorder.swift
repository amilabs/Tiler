import Foundation
import TilerCore

/// Appends every touch frame to a JSONL file (crash-safe, line-per-frame).
/// Enabled by `--record-touches <path>`; used to capture golden traces (task 8.1).
/// Thread-confined to the TouchStream queue.
public final class TraceRecorder {
    private let handle: FileHandle
    public private(set) var framesWritten = 0

    public init(path: String) throws {
        FileManager.default.createFile(atPath: path, contents: nil)
        guard let h = FileHandle(forWritingAtPath: path) else {
            throw CocoaError(.fileWriteUnknown)
        }
        handle = h
    }

    public func append(_ frame: TouchFrame) {
        guard let data = try? TraceIO.encodeLine(frame) else { return }
        try? handle.write(contentsOf: data)
        framesWritten += 1
    }

    deinit {
        try? handle.close()
    }
}
