/// Deterministic 3-finger swipe recognizer (design.md §2, specs/gestures/spec.md).
/// Pure logic: feed frames in timestamp order, get at most one action per physical gesture.
/// Not thread-safe by design — call from a single queue (TouchStream's).
public final class GestureRecognizer {
    private struct FingerKey: Hashable {
        let device: UInt64
        let finger: Int32
    }

    private enum Phase {
        case idle       // waiting for a clean exact-3 session to stabilize
        case tracking   // armed: accumulating centroid movement from baseline
        case lockout    // fired or aborted: dead until full lift-off + cooldown
    }

    private enum Direction {
        case left, right, up, down
    }

    private var tun: Tunables
    /// Staged by updateTunables; applied only from a clean idle pad (never mid-gesture).
    private var pendingTunables: Tunables?

    /// Opt-in diagnostic side-channel (nil = zero cost): emits a concise line at every
    /// confirmed decision so a false positive can be caught with its evidence (movement,
    /// speed, finger count, modifiers). Does NOT affect recognition.
    public var diagnostic: ((String) -> Void)?

    // Phase and per-session bookkeeping. A "session" spans from the first contact
    // after a clean idle pad to full lift-off.
    private var phase: Phase = .idle
    private var lastFrameTimestamp: Double?
    private var zeroContactsSince: Double?
    private var sessionStart: Double?
    private var sessionDirty = false
    private var firstThreeAt: Double?
    private var previousActiveCount = 0
    private var armingStreak = 0

    // Tracking (armed) state.
    private var armTimestamp = 0.0
    private var trackedFingers: Set<FingerKey> = []
    private var baselineX = 0.0
    private var baselineY = 0.0
    private var peakDx = 0.0
    private var peakDy = 0.0
    private var confirmStreak = 0
    private var pendingDirection: Direction?

    public init(tunables: Tunables = .default) {
        tun = tunables
    }

    /// Stage new tunables (e.g. from calibration). Applied on the next frame that
    /// finds the pad in a clean idle state — a gesture already in progress is
    /// evaluated entirely with the old values (gestures spec).
    public func updateTunables(_ new: Tunables) {
        pendingTunables = new
        applyPendingTunablesIfIdle()
    }

    private func applyPendingTunablesIfIdle() {
        guard let pending = pendingTunables, phase == .idle, sessionStart == nil else { return }
        tun = pending
        pendingTunables = nil
    }

    /// Process one frame. `cmdHeld`/`shiftHeld` are modifier snapshots at frame time.
    /// Returns an action only at the exact moment a gesture is confirmed.
    public func process(_ frame: TouchFrame, cmdHeld: Bool = false,
                        shiftHeld: Bool = false) -> GestureAction? {
        let t = frame.timestamp

        // Stream silence implies zero contacts for the whole gap: if the gap covers
        // lift-off quiet time plus cooldown, the pad is clean again.
        if let last = lastFrameTimestamp, t - last >= tun.liftOffQuiet + tun.cooldown {
            resetToCleanIdle()
        }
        applyPendingTunablesIfIdle()
        lastFrameTimestamp = t

        let active = frame.contacts.filter { c in
            (c.state == .making || c.state == .touching)
                && c.size >= tun.minContactSize
                && c.size <= tun.palmSizeThreshold
        }
        let palmPresent = frame.contacts.contains { c in
            (c.state == .making || c.state == .touching) && c.size > tun.palmSizeThreshold
        }

        if active.isEmpty && !palmPresent {
            return processZeroContacts(at: t)
        }
        zeroContactsSince = nil

        updateSession(activeCount: active.count, palmPresent: palmPresent, at: t)

        switch phase {
        case .lockout:
            return nil
        case .idle:
            processIdle(active: active, palmPresent: palmPresent, at: t)
            return nil
        case .tracking:
            return processTracking(active: active, palmPresent: palmPresent, at: t,
                                   cmdHeld: cmdHeld, shiftHeld: shiftHeld)
        }
    }

    // MARK: - Frame handling

    private func processZeroContacts(at t: Double) -> GestureAction? {
        previousActiveCount = 0
        if zeroContactsSince == nil { zeroContactsSince = t }
        if phase == .tracking {
            // Fingers vanished before confirmation: cancelled gesture.
            lockoutNow()
        }
        if let z = zeroContactsSince, t - z >= tun.liftOffQuiet + tun.cooldown {
            resetToCleanIdle()
            zeroContactsSince = z // still zero; keep the quiet clock running
        }
        return nil
    }

    private func updateSession(activeCount: Int, palmPresent: Bool, at t: Double) {
        if sessionStart == nil {
            sessionStart = t
            sessionDirty = false
            firstThreeAt = nil
        }
        if palmPresent { sessionDirty = true }
        if activeCount > 3 { sessionDirty = true }
        if activeCount < previousActiveCount { sessionDirty = true }
        if activeCount == 3, firstThreeAt == nil {
            firstThreeAt = t
            if let s = sessionStart, t - s > tun.touchdownAssemblyWindow {
                sessionDirty = true
            }
        }
        previousActiveCount = activeCount
    }

    private func processIdle(active: [Contact], palmPresent: Bool, at t: Double) {
        guard !sessionDirty, !palmPresent, active.count == 3 else {
            armingStreak = 0
            return
        }
        armingStreak += 1
        guard armingStreak >= tun.stableArmFrames else { return }

        phase = .tracking
        armTimestamp = t
        trackedFingers = Set(active.map { FingerKey(device: $0.deviceID, finger: $0.fingerID) })
        (baselineX, baselineY) = centroid(active)
        peakDx = 0
        peakDy = 0
        confirmStreak = 0
        pendingDirection = nil
    }

    private func processTracking(active: [Contact], palmPresent: Bool,
                                 at t: Double, cmdHeld: Bool, shiftHeld: Bool) -> GestureAction? {
        let keys = Set(active.map { FingerKey(device: $0.deviceID, finger: $0.fingerID) })
        guard !palmPresent, active.count == 3, keys == trackedFingers else {
            lockoutNow()
            return nil
        }
        guard t - armTimestamp <= tun.maxGestureDuration else {
            lockoutNow()
            return nil
        }

        let (cx, cy) = centroid(active)
        let dx = cx - baselineX
        let dy = cy - baselineY
        if abs(dx) > abs(peakDx) { peakDx = dx }
        if abs(dy) > abs(peakDy) { peakDy = dy }

        // Reversal check on the dominant axis: backtracking past tolerance aborts.
        let (peak, current) = abs(peakDx) >= abs(peakDy) ? (peakDx, dx) : (peakDy, dy)
        let backtrack = peak >= 0 ? peak - current : current - peak
        if backtrack > tun.reversalTolerance * max(abs(peak), tun.minDisplacement) {
            lockoutNow()
            return nil
        }

        let progress = max(abs(dx), abs(dy))
        guard progress >= tun.minDisplacement else {
            confirmStreak = 0
            return nil
        }

        // Direction dominance on the cumulative vector. Ambiguous at threshold = abort.
        let direction: Direction
        if abs(dx) >= tun.horizontalDominance * abs(dy) {
            direction = dx < 0 ? .left : .right
        } else if abs(dy) >= tun.verticalDominance * abs(dx) {
            direction = dy > 0 ? .up : .down
        } else {
            lockoutNow()
            return nil
        }

        if pendingDirection != direction {
            pendingDirection = direction
            confirmStreak = 0
        }

        let elapsed = t - armTimestamp
        guard elapsed > 0, progress / elapsed >= tun.minMeanSpeed else {
            confirmStreak = 0
            return nil
        }

        confirmStreak += 1
        guard confirmStreak >= tun.confirmSamples else { return nil }

        // Confirmed: exactly one decision per physical gesture.
        lockoutNow()
        let action: GestureAction?
        switch direction {
        case .down:
            action = nil // deliberately not implemented
        case .up:
            // ⇧+up = center-third (the double-press ↑ analog); ⌘+up stays silent.
            action = cmdHeld ? nil : GestureAction(direction: .up, nextDisplay: false,
                                                   thirdWidth: shiftHeld)
        case .left:
            action = GestureAction(direction: .left, nextDisplay: cmdHeld, thirdWidth: shiftHeld)
        case .right:
            action = GestureAction(direction: .right, nextDisplay: cmdHeld, thirdWidth: shiftHeld)
        }
        emitDiagnostic(direction, action: action, dx: dx, dy: dy, progress: progress,
                       elapsed: elapsed, fingers: active.count, cmdHeld: cmdHeld, shiftHeld: shiftHeld)
        return action
    }

    private func emitDiagnostic(_ direction: Direction, action: GestureAction?,
                                dx: Double, dy: Double, progress: Double, elapsed: Double,
                                fingers: Int, cmdHeld: Bool, shiftHeld: Bool) {
        guard let diagnostic else { return }
        func r(_ v: Double) -> Double { (v * 10).rounded() / 10 }
        let speed = elapsed > 0 ? r(progress / elapsed) : 0
        let dir = "\(direction)"
        let act = action.map { "\($0.direction.rawValue)\($0.thirdWidth ? "-third" : "")\($0.nextDisplay ? "-next" : "")" } ?? "none"
        diagnostic("fire dir=\(dir) action=\(act) dx=\(r(dx)) dy=\(r(dy)) prog=\(r(progress)) "
            + "dt=\(r(elapsed)) speed=\(speed) fingers=\(fingers) cmd=\(cmdHeld) shift=\(shiftHeld)")
    }

    // MARK: - State transitions

    private func lockoutNow() {
        phase = .lockout
        sessionDirty = true
        armingStreak = 0
        confirmStreak = 0
        pendingDirection = nil
        trackedFingers = []
    }

    private func resetToCleanIdle() {
        phase = .idle
        sessionStart = nil
        sessionDirty = false
        firstThreeAt = nil
        previousActiveCount = 0
        armingStreak = 0
        confirmStreak = 0
        pendingDirection = nil
        trackedFingers = []
        zeroContactsSince = nil
    }

    private func centroid(_ contacts: [Contact]) -> (Double, Double) {
        let n = Double(contacts.count)
        let sx = contacts.reduce(0.0) { $0 + $1.x }
        let sy = contacts.reduce(0.0) { $0 + $1.y }
        return (sx / n, sy / n)
    }
}
