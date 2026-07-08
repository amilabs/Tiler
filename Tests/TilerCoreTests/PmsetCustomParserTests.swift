import Foundation
import Testing
@testable import TilerCore

// Deep Sleep profile parsing (power spec). Reads the "Battery Power:" section of
// `pmset -g custom`, stopping at the next section header. Fixture is real captured
// output; synthetic cases lock the section boundary and multi-word key handling.
@Suite("pmset custom parser") struct PmsetCustomParserTests {
    private func fixture() throws -> String {
        let url = try #require(Bundle.module.url(forResource: "pmset-custom",
                                                 withExtension: "txt", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func parsesBatteryKeysFromFixture() throws {
        let s = PmsetCustomParser.batterySettings(from: try fixture())
        #expect(s["hibernatemode"] == "3")
        #expect(s["powernap"] == "0")
        #expect(s["tcpkeepalive"] == "0")
        #expect(s["proximitywake"] == nil)   // absent on this Mac
    }

    @Test func picksBatterySectionNotAC() throws {
        // Battery displaysleep is 2, AC is 10 in the fixture — proves we read Battery.
        #expect(PmsetCustomParser.batterySettings(from: try fixture())["displaysleep"] == "2")
    }

    @Test func handlesMultiWordKeys() throws {
        #expect(PmsetCustomParser.batterySettings(from: try fixture())["Sleep On Power Button"] == "1")
    }

    @Test func stopsAtNextHeader() {
        let text = [
            "Battery Power:",
            " hibernatemode        25",
            " powernap             0",
            "AC Power:",
            " hibernatemode        3",
        ].joined(separator: "\n")
        let s = PmsetCustomParser.batterySettings(from: text)
        #expect(s["hibernatemode"] == "25")   // battery value, not AC's 3
        #expect(s.count == 2)
    }

    @Test func missingBatterySectionYieldsEmpty() {
        let onlyAC = ["AC Power:", " hibernatemode        3"].joined(separator: "\n")
        #expect(PmsetCustomParser.batterySettings(from: onlyAC).isEmpty)
    }
}
