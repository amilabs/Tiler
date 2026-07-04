import Foundation

/// JSONL persistence for touch traces: one `TouchFrame` per line.
/// Used by `--record-touches` (append-as-you-go, crash-safe) and by golden-trace
/// replay in tests.
public enum TraceIO {
    public static func encodeLine(_ frame: TouchFrame) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(frame)
        data.append(0x0A)
        return data
    }

    public static func write(_ frames: [TouchFrame], to url: URL) throws {
        var data = Data()
        for frame in frames {
            data.append(try encodeLine(frame))
        }
        try data.write(to: url, options: .atomic)
    }

    public static func read(from url: URL) throws -> [TouchFrame] {
        let decoder = JSONDecoder()
        let raw = try Data(contentsOf: url)
        return try raw.split(separator: 0x0A)
            .filter { !$0.isEmpty }
            .map { try decoder.decode(TouchFrame.self, from: Data($0)) }
    }
}
