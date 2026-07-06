import Foundation
import TilerCore

/// Persisted app settings (settings spec). UserDefaults-backed; the suite is
/// injectable for tests. Changes apply immediately via `onChange`.
@MainActor
public final class SettingsStore {
    private enum Key {
        static let gestures = "gesturesEnabled"
        static let windowHotkeys = "windowHotkeysEnabled"
        static let utilityHotkeys = "utilityHotkeysEnabled"
        static let tunables = "tunablesOverride"
    }

    public var onChange: ((SettingsStore) -> Void)?

    private let defaults: UserDefaults

    public var gesturesEnabled: Bool {
        didSet {
            guard gesturesEnabled != oldValue else { return }
            defaults.set(gesturesEnabled, forKey: Key.gestures)
            onChange?(self)
        }
    }

    /// Window-tiling hotkeys (⌃⇧ / ⌘⌃⇧ arrows). OFF by default: the owner drives
    /// windows by gestures; the legacy single hotkeysEnabled key was dropped.
    public var windowHotkeysEnabled: Bool {
        didSet {
            guard windowHotkeysEnabled != oldValue else { return }
            defaults.set(windowHotkeysEnabled, forKey: Key.windowHotkeys)
            onChange?(self)
        }
    }

    /// Utility hotkeys (⌃A lock screen). ON by default.
    public var utilityHotkeysEnabled: Bool {
        didSet {
            guard utilityHotkeysEnabled != oldValue else { return }
            defaults.set(utilityHotkeysEnabled, forKey: Key.utilityHotkeys)
            onChange?(self)
        }
    }

    /// First-run flag for the Guide window. Pure UX bookkeeping: intentionally
    /// does NOT fire onChange (no engine wiring depends on it).
    public var hasSeenGuide: Bool {
        didSet {
            guard hasSeenGuide != oldValue else { return }
            defaults.set(hasSeenGuide, forKey: "hasSeenGuide")
        }
    }

    /// Personal calibration result; nil = stock defaults (calibration spec).
    public var tunablesOverride: Tunables? {
        didSet {
            guard tunablesOverride != oldValue else { return }
            if let value = tunablesOverride, let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: Key.tunables)
            } else {
                defaults.removeObject(forKey: Key.tunables)
            }
            onChange?(self)
        }
    }

    /// Effective tunables = stock defaults with the personal override applied.
    public var effectiveTunables: Tunables {
        tunablesOverride ?? .default
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        gesturesEnabled = defaults.object(forKey: Key.gestures) as? Bool ?? true
        windowHotkeysEnabled = defaults.object(forKey: Key.windowHotkeys) as? Bool ?? false
        utilityHotkeysEnabled = defaults.object(forKey: Key.utilityHotkeys) as? Bool ?? true
        hasSeenGuide = defaults.object(forKey: "hasSeenGuide") as? Bool ?? false
        if let data = defaults.data(forKey: Key.tunables) {
            tunablesOverride = try? JSONDecoder().decode(Tunables.self, from: data)
        }
    }
}
