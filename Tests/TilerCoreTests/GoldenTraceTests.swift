import Foundation
import Testing
@testable import TilerCore

// Golden traces (task 8.2): real-trackpad recordings frozen with their machine-
// generated expected action sequences (TraceCheck --write-expected). Any recognizer
// change that alters behavior on real data — new false positive, lost swipe,
// double-fire — breaks the sequence equality here.
@Suite("Golden traces") struct GoldenTraceTests {

    @Test func allGoldenTracesReplayToFrozenActions() throws {
        let traces = Bundle.module.urls(forResourcesWithExtension: "jsonl",
                                        subdirectory: "Fixtures") ?? []
        #expect(!traces.isEmpty, "no golden fixtures bundled")

        for trace in traces {
            let expectedURL = trace.deletingPathExtension().appendingPathExtension("expected.json")
            let expected = try JSONDecoder().decode([GestureAction].self,
                                                    from: Data(contentsOf: expectedURL))
            let frames = try TraceIO.read(from: trace)
            let recognizer = GestureRecognizer()
            let actions = frames.compactMap { recognizer.process($0) }
            #expect(actions == expected,
                    "\(trace.lastPathComponent): got \(actions.count) actions, frozen \(expected.count)")
        }
    }
}
