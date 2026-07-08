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
        static let keepDisplayAwake = "keepDisplayAwake"
        static let batteryFloorPercent = "batteryFloorPercent"
        static let deepSleepOnBattery = "deepSleepOnBattery"
        static let powerSnapshot = "powerSnapshot"
        static let powerDebugLogging = "powerDebugLogging"
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

    // MARK: - Power (add-power-control)

    /// Keep Awake sessions hold the display awake too. Default off (system may sleep
    /// the display while staying awake).
    public var keepDisplayAwake: Bool {
        didSet {
            guard keepDisplayAwake != oldValue else { return }
            defaults.set(keepDisplayAwake, forKey: Key.keepDisplayAwake)
            onChange?(self)
        }
    }

    /// Auto-stop floor for an active session on battery: 0 = off, else 30/20/10.
    public var batteryFloorPercent: Int {
        didSet {
            guard batteryFloorPercent != oldValue else { return }
            defaults.set(batteryFloorPercent, forKey: Key.batteryFloorPercent)
            onChange?(self)
        }
    }

    /// Stored *intent* for the battery-side Deep Sleep profile. Reconciled against
    /// actual `pmset -g custom` at launch (reality wins), so this may be corrected
    /// without a user action.
    public var deepSleepOnBattery: Bool {
        didSet {
            guard deepSleepOnBattery != oldValue else { return }
            defaults.set(deepSleepOnBattery, forKey: Key.deepSleepOnBattery)
            onChange?(self)
        }
    }

    /// Snapshot of the pmset keys Deep Sleep overwrote, for verbatim restore.
    /// Bookkeeping only: intentionally does NOT fire onChange (like hasSeenGuide).
    public var powerSnapshot: [String: String]? {
        didSet {
            guard powerSnapshot != oldValue else { return }
            if let value = powerSnapshot, let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: Key.powerSnapshot)
            } else {
                defaults.removeObject(forKey: Key.powerSnapshot)
            }
        }
    }

    /// Opt-in diagnostic power-event logging (owner-driven multi-day runs).
    /// Bookkeeping only: no onChange (the UI drives the log adapter directly).
    public var powerDebugLogging: Bool {
        didSet {
            guard powerDebugLogging != oldValue else { return }
            defaults.set(powerDebugLogging, forKey: Key.powerDebugLogging)
        }
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
        keepDisplayAwake = defaults.object(forKey: Key.keepDisplayAwake) as? Bool ?? false
        batteryFloorPercent = defaults.object(forKey: Key.batteryFloorPercent) as? Int ?? 20
        deepSleepOnBattery = defaults.object(forKey: Key.deepSleepOnBattery) as? Bool ?? false
        if let data = defaults.data(forKey: Key.powerSnapshot) {
            powerSnapshot = try? JSONDecoder().decode([String: String].self, from: data)
        }
        powerDebugLogging = defaults.object(forKey: Key.powerDebugLogging) as? Bool ?? false
    }
}
