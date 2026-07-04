import Foundation

/// A system setting that competes with Tiler's 3-finger gestures (app-shell spec).
public struct SystemConflict: Equatable, Sendable {
    public let title: String
    public let guidance: String

    public init(title: String, guidance: String) {
        self.title = title
        self.guidance = guidance
    }
}

/// Read-only detection of conflicting system trackpad gestures. Tiler never
/// modifies system settings — it only warns. The preference reader is injected
/// for testability; the real one uses CFPreferences.
public struct ConflictDiagnostics: Sendable {
    public typealias Reader = @Sendable (_ domain: String, _ key: String) -> Int?

    /// Built-in trackpad and Magic Trackpad domains — both must be checked.
    private static let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]

    private let read: Reader

    public init(reader: @escaping Reader = ConflictDiagnostics.defaultsReader) {
        self.read = reader
    }

    public static let defaultsReader: Reader = { domain, key in
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Int
    }

    public func conflicts() -> [SystemConflict] {
        var found: [SystemConflict] = []

        if anyDomain("TrackpadThreeFingerDrag", matches: { $0 == 1 }) {
            found.append(SystemConflict(
                title: "Three Finger Drag is enabled",
                guidance: "System Settings → Accessibility → Pointer Control → "
                    + "Trackpad Options: turn off three-finger drag — it consumes "
                    + "3-finger movements before Tiler sees them."
            ))
        }
        if anyDomain("TrackpadThreeFingerHorizSwipeGesture", matches: { $0 != 0 }) {
            found.append(SystemConflict(
                title: "System 3-finger horizontal swipes are enabled",
                guidance: "System Settings → Trackpad → More Gestures: set “Swipe "
                    + "between full-screen applications” to four fingers or off."
            ))
        }
        if anyDomain("TrackpadThreeFingerVertSwipeGesture", matches: { $0 != 0 }) {
            found.append(SystemConflict(
                title: "Mission Control / App Exposé 3-finger swipes are enabled",
                guidance: "System Settings → Trackpad → More Gestures: set Mission "
                    + "Control and App Exposé to four fingers or off."
            ))
        }
        return found
    }

    private func anyDomain(_ key: String, matches predicate: (Int) -> Bool) -> Bool {
        Self.domains.contains { domain in
            read(domain, key).map(predicate) ?? false
        }
    }
}
