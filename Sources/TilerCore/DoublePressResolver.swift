/// Pure double-press disambiguation for Ctrl+Shift+↑ (hotkeys spec).
/// The driver (HotkeyController) feeds presses and calls `resolveExpired` from a
/// timer scheduled at `deadline`.
public struct DoublePressResolver {
    public enum Decision: Equatable, Sendable {
        case maximize
        case centerThird
    }

    private let window: Double
    private var pendingSince: Double?

    public init(window: Double) {
        self.window = window
    }

    /// When the driver's expiry timer should fire, if a press is pending.
    public var deadline: Double? {
        pendingSince.map { $0 + window }
    }

    /// A press of the hotkey. Returns `.centerThird` iff it completes a double press.
    public mutating func registerPress(at t: Double) -> Decision? {
        if let pending = pendingSince, t - pending <= window {
            pendingSince = nil
            return .centerThird
        }
        // No pending press, or a stale one whose expiry the driver missed:
        // either way this press opens a fresh window.
        pendingSince = t
        return nil
    }

    /// Timer callback. Returns `.maximize` once when a pending press expires unpaired.
    public mutating func resolveExpired(now t: Double) -> Decision? {
        guard let pending = pendingSince, t - pending > window else { return nil }
        pendingSince = nil
        return .maximize
    }
}
