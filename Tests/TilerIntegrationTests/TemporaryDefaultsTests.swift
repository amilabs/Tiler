import Foundation
import Testing

// Test hygiene: a throwaway defaults suite must not outlive its test, and must not
// touch ~/Library/Preferences, where cfprefsd never deletes a suite's plist.
@Suite("Temporary defaults") struct TemporaryDefaultsTests {

    @Test func storageLivesInItsOwnDirectoryAndGoesOnRelease() throws {
        var scratch: TemporaryDefaults? = TemporaryDefaults()
        let directory = scratch!.directory.path
        scratch!.defaults.set(true, forKey: "probe")
        // cfprefsd writes asynchronously; wait for the file so the check below is not vacuous.
        try #require(waitUntil { (try? FileManager.default.contentsOfDirectory(atPath: directory))?.isEmpty == false })

        scratch = nil
        #expect(!FileManager.default.fileExists(atPath: directory))
    }

    @Test func secondInstanceSeesWrites() {
        let scratch = TemporaryDefaults()
        scratch.defaults.set(["a": "b"], forKey: "probe")
        let other = UserDefaults(suiteName: scratch.suiteName)
        #expect(other?.dictionary(forKey: "probe") as? [String: String] == ["a": "b"])
    }

    @Test func eachInstanceGetsItsOwnEmptySuite() {
        let first = TemporaryDefaults()
        let second = TemporaryDefaults()
        first.defaults.set(1, forKey: "probe")
        #expect(first.suiteName != second.suiteName)
        #expect(second.defaults.object(forKey: "probe") == nil)
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            usleep(10_000)
        }
        return true
    }
}
