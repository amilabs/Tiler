import Foundation

/// A fresh, empty UserDefaults suite for one test, kept out of ~/Library/Preferences.
///
/// A plainly named suite persists `~/Library/Preferences/<name>.plist`, and on macOS 26
/// cfprefsd never deletes that file: removing the domain (even `defaults delete`) leaves
/// an empty plist behind, and unlinking it races with cfprefsd's delayed writes, which
/// recreate it seconds later. So the suite is named by an absolute path inside a private
/// temporary directory (the CFPreferences path-domain form `defaults` also accepts), and
/// releasing this object removes that directory.
///
/// Hold it in a stored property of the test suite: Swift Testing creates one suite
/// instance per test and releases it afterwards.
final class TemporaryDefaults {
    let directory: URL
    let suiteName: String
    let defaults: UserDefaults

    init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiler-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = directory.appendingPathComponent("defaults").path
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}
