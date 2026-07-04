import Foundation

/// Persisted app settings (settings spec). UserDefaults-backed; the suite is
/// injectable for tests. Changes apply immediately via `onChange`.
@MainActor
public final class SettingsStore {
    private enum Key {
        static let gestures = "gesturesEnabled"
        static let hotkeys = "hotkeysEnabled"
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

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        gesturesEnabled = defaults.object(forKey: Key.gestures) as? Bool ?? true
        hotkeysEnabled = defaults.object(forKey: Key.hotkeys) as? Bool ?? true
    }
}
