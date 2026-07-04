import Foundation
import TilerCore

// Replays a recorded JSONL touch trace through GestureRecognizer and reports every
// fired action with its time offset and gap-delimited segment index.
// Usage: TraceCheck <trace.jsonl> [gapSeconds]

guard CommandLine.arguments.count > 1 else {
    print("usage: TraceCheck <trace.jsonl> [gapSeconds]")
    exit(2)
}
let path = CommandLine.arguments[1]
let gap = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 1.0 : 1.0

let frames = try TraceIO.read(from: URL(fileURLWithPath: path))
guard let t0 = frames.first?.timestamp else {
    print("empty trace")
    exit(1)
}

var segmentStarts: [Double] = []
var previous: Double?
for frame in frames {
    if let p = previous, frame.timestamp - p > gap {
        segmentStarts.append(frame.timestamp)
    }
    previous = frame.timestamp
}
let starts = segmentStarts
func segment(of t: Double) -> Int {
    starts.lastIndex(where: { $0 <= t }).map { $0 + 1 } ?? 0
}

let recognizer = GestureRecognizer()
var total = 0
var perSegment: [Int: [String]] = [:]
for frame in frames {
    if let action = recognizer.process(frame) {
        let seg = segment(of: frame.timestamp)
        total += 1
        perSegment[seg, default: []].append(action.direction.rawValue)
        print(String(format: "t=%7.1fs  seg=%2d  action=%@", frame.timestamp - t0, seg, action.direction.rawValue))
    }
}
print("---")
print("total actions: \(total)")
for seg in perSegment.keys.sorted() {
    print("  seg \(seg): \(perSegment[seg]!.joined(separator: " "))")
}

// --write-expected: freeze the action sequence next to the trace for regression tests.
if CommandLine.arguments.contains("--write-expected") {
    let replayer = GestureRecognizer()
    let actions = frames.compactMap { replayer.process($0) }
    let out = URL(fileURLWithPath: path).deletingPathExtension()
        .appendingPathExtension("expected.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(actions).write(to: out)
    print("expected actions written: \(out.path) (\(actions.count) actions)")
}
