import Foundation
import TilerCore

/// Persisted app settings (settings spec). UserDefaults-backed; the suite is
/// injectable for tests. Changes apply immediately via `onChange`.
@MainActor
public final class SettingsStore {
    private enum Key {
        static let gestures = "gesturesEnabled"
        static let hotkeys = "hotkeysEnabled"
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

    public var hotkeysEnabled: Bool {
        didSet {
            guard hotkeysEnabled != oldValue else { return }
            defaults.set(hotkeysEnabled, forKey: Key.hotkeys)
            onChange?(self)
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
        hotkeysEnabled = defaults.object(forKey: Key.hotkeys) as? Bool ?? true
        if let data = defaults.data(forKey: Key.tunables) {
            tunablesOverride = try? JSONDecoder().decode(Tunables.self, from: data)
        }
    }
}
