import Foundation

/// Pure decisions for touch-stream recovery (app-shell "Gesture stream recovery").
/// The system layer feeds in device signatures and ages; this decides whether the
/// stream must be rebuilt. Field context: the MultitouchSupport stream can die
/// without a system sleep (observed 2026-07-15), so recovery cannot key on wake
/// alone — it detects death by evidence: stale device identity, or prolonged frame
/// silence while the user is demonstrably at the machine.
public enum StreamHealthPolicy {

    /// A fresh enumeration that differs from what the stream attached to means the
    /// attached refs are stale — rebuild. Signatures are device-ID multisets
    /// (sorted-compare; order carries no meaning). `current == nil` means the fresh
    /// enumeration failed: no information, never drift.
    public static func deviceDrift(attached: [UInt64], current: [UInt64]?) -> Bool {
        guard let current else { return false }
        return attached.sorted() != current.sorted()
    }

    /// Silence self-heal: rebuild only when the stream has been frame-silent for
    /// `minSilence` while pointer/scroll HID activity is at most `maxHIDAge` old
    /// (the user is moving the cursor, we hear nothing) on an unlocked screen, and
    /// the previous rebuild is at least `cooldown` behind — an external-mouse-only
    /// user legitimately produces "silent trackpad + live cursor" forever, and the
    /// cooldown caps that churn at one idempotent stop/start per period.
    public static func shouldSelfHeal(
        silentFor: TimeInterval,
        hidAgo: TimeInterval?,
        sinceLastRebuild: TimeInterval,
        screenLocked: Bool,
        minSilence: TimeInterval = 600,
        maxHIDAge: TimeInterval = 60,
        cooldown: TimeInterval = 600
    ) -> Bool {
        guard !screenLocked, let hidAgo else { return false }
        return silentFor >= minSilence && hidAgo <= maxHIDAge && sinceLastRebuild >= cooldown
    }

    /// Display-change trigger (fix-rebuild-gesture-loss, 2026-07-31 incident: a
    /// charger unplug fired display changes while the stream was alive, and the
    /// unconditional rebuilds ate in-flight swipes). Rebuild only when it might be
    /// needed and cannot hurt: a rebuild `< coalesce` ago means the burst is
    /// already handled; a frame within `aliveWindow` proves the stream survived
    /// the change (and fingers may be mid-stroke — a rebuild would eat it). An
    /// idle-and-quiet stream rebuilds: possibly dead, and nothing is in flight.
    public static func displayChangeRebuild(
        silentFor: TimeInterval,
        sinceLastRebuild: TimeInterval,
        aliveWindow: TimeInterval = 1.0,
        coalesce: TimeInterval = 10
    ) -> Bool {
        guard sinceLastRebuild >= coalesce else { return false }
        return silentFor >= aliveWindow
    }
}
