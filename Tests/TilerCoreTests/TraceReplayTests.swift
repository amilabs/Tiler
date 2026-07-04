import Foundation
import Testing
@testable import TilerCore

// TraceIO roundtrip + replay parity: a recorded trace fed back into a fresh
// recognizer must reproduce the exact same actions as the live stream did.
@Suite("Trace replay") struct TraceReplayTests {

    /// Raw frames of a canonical left swipe (arm, move, lift), 120 Hz.
    private func leftSwipeFrames(start: Double = 10.0) -> [TouchFrame] {
        let dt = 1.0 / 120.0
        var t = start
        var frames: [TouchFrame] = []
        for _ in 0..<5 {
            frames.append(TouchFrame(timestamp: t, contacts: fingers(3, at: 0.5, 0.5)))
            t += dt
        }
        for i in 1...18 {
            let f = Double(i) / 18.0
            frames.append(TouchFrame(timestamp: t, contacts: fingers(3, at: 0.5 - 0.15 * f, 0.5)))
            t += dt
        }
        frames.append(TouchFrame(timestamp: t, contacts: []))
        return frames
    }

    private func replay(_ frames: [TouchFrame]) -> [GestureAction] {
        let recognizer = GestureRecognizer()
        return frames.compactMap { recognizer.process($0) }
    }

    @Test func jsonlRoundtripPreservesFrames() throws {
        let frames = leftSwipeFrames()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiler-trace-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        try TraceIO.write(frames, to: url)
        let decoded = try TraceIO.read(from: url)
        #expect(decoded == frames)
    }

    @Test func replayedTraceReproducesActions() throws {
        let frames = leftSwipeFrames()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiler-trace-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let liveActions = replay(frames)
        #expect(liveActions == [GestureAction(direction: .left, nextDisplay: false)])

        try TraceIO.write(frames, to: url)
        let replayedActions = replay(try TraceIO.read(from: url))
        #expect(replayedActions == liveActions)
    }

    @Test func emptyTraceFileYieldsNoFramesAndNoActions() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiler-trace-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data().write(to: url)
        let frames = try TraceIO.read(from: url)
        #expect(frames.isEmpty)
        #expect(replay(frames).isEmpty)
    }
}
