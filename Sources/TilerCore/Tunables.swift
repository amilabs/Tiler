/// Every gesture/hotkey threshold in one place (design.md §2). Values are refined
/// against golden traces in task 8.2 — change them here, nowhere else.
public struct Tunables: Sendable {
    /// Contacts below this size are ignored entirely (kills size=0 stale artifacts).
    public var minContactSize: Double = 0.05
    /// Contacts above this size are palm-class: never counted, and block arming.
    public var palmSizeThreshold: Double = 2.0
    /// Consecutive frames with exactly 3 active contacts required to arm.
    public var stableArmFrames: Int = 4
    /// All 3 fingers must touch down within this window (seconds) of the session's
    /// first touch; a later third finger (e.g. added mid-scroll) poisons the session.
    public var touchdownAssemblyWindow: Double = 0.060
    /// Min centroid displacement from the arm baseline (normalized units).
    public var minDisplacement: Double = 0.10
    /// Horizontal swipe requires |dx| >= horizontalDominance * |dy| (≈ ≤26.6°).
    public var horizontalDominance: Double = 2.0
    /// Vertical swipe requires |dy| >= verticalDominance * |dx| (≈ ≤32°).
    public var verticalDominance: Double = 1.6
    /// Consecutive frames satisfying all confirm conditions required to fire.
    public var confirmSamples: Int = 3
    /// Min mean speed (normalized units per second) measured from arm time.
    public var minMeanSpeed: Double = 0.5
    /// Max seconds from arming to confirmation; slower gestures abort.
    public var maxGestureDuration: Double = 0.600
    /// Max backtrack on the dominant axis, as a fraction of max(|extremum|, minDisplacement).
    public var reversalTolerance: Double = 0.08
    /// Seconds with zero active contacts required to count as full lift-off.
    public var liftOffQuiet: Double = 0.080
    /// Seconds after lift-off before the recognizer may re-arm.
    public var cooldown: Double = 0.250
    /// Hotkey double-press disambiguation window (Ctrl+Shift+↑), seconds.
    public var doublePressWindow: Double = 0.300
    /// AXIsProcessTrusted poll interval while permission is missing, seconds.
    public var permissionPollInterval: Double = 2.0

    public static let `default` = Tunables()
    public init() {}
}
