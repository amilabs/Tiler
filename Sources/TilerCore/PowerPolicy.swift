import Foundation

/// Keep Awake session state machine (power spec). Pure decision core: the clock and
/// battery are injected via `now:` / `.power`, and the machine returns effects for the
/// system layer (`AwakeController`, `DisableSleepGovernor`, notifier) to perform. It
/// never touches IOKit, so it is exhaustively unit-tested.

/// What assertions a live session wants held.
public struct AssertionSpec: Equatable, Sendable {
    /// Keep the display awake too (`PreventUserIdleDisplaySleep`).
    public var displayAwake: Bool
    /// Hold plain `PreventSystemSleep` (the clamshell leg; effective on AC alone).
    public var systemSleepBlock: Bool
    public init(displayAwake: Bool, systemSleepBlock: Bool) {
        self.displayAwake = displayAwake
        self.systemSleepBlock = systemSleepBlock
    }
}

public enum KeepAwakeStopReason: String, Equatable, Sendable {
    case user, expired, batteryFloor
}

/// A power-source reading. `percent == nil` on desktops (no battery).
public struct PowerStatus: Equatable, Sendable {
    public var percent: Int?
    public var onBattery: Bool
    public init(percent: Int?, onBattery: Bool) {
        self.percent = percent
        self.onBattery = onBattery
    }
}

public enum PowerCommand: Equatable, Sendable {
    case start(clamshell: Bool, duration: TimeInterval?)
    case stop
    case tick
    case power(PowerStatus)
    case setDisplayAwake(Bool)
    case setFloor(Int)              // 0 = off
    case clamshellArmFailed         // auth cancelled / arm error
}

public enum PowerEffect: Equatable, Sendable {
    case acquire(AssertionSpec)
    case release(KeepAwakeStopReason)
    case armClamshell(deadline: Date?)
    case disarmClamshell
    case notifyFloorStop(percent: Int)
}

public struct PowerPolicy: Sendable {
    public private(set) var isActive: Bool = false
    public private(set) var clamshell: Bool = false
    public private(set) var deadline: Date?

    private var displayAwake: Bool
    private var floorPercent: Int
    /// Set when a battery-floor stop ends the session; reset only by an explicit
    /// `start`. Guards against re-stopping/re-notifying within one session (the
    /// "no auto-restart" invariant is also enforced by `isActive`, this is belt-and-braces).
    private var floorTripped = false

    public init(displayAwake: Bool, floorPercent: Int) {
        self.displayAwake = displayAwake
        self.floorPercent = floorPercent
    }

    private var currentSpec: AssertionSpec {
        AssertionSpec(displayAwake: displayAwake, systemSleepBlock: clamshell)
    }

    /// Time left on a timed session, or nil when off or indefinite.
    public func remaining(now: Date) -> TimeInterval? {
        guard isActive, let deadline else { return nil }
        return deadline.timeIntervalSince(now)
    }

    public mutating func handle(_ command: PowerCommand, now: Date) -> [PowerEffect] {
        switch command {
        case let .start(clamshell, duration):
            var effects: [PowerEffect] = []
            if isActive {                        // replacement: tear the old one down first
                if self.clamshell { effects.append(.disarmClamshell) }
                effects.append(.release(.user))
            }
            isActive = true
            self.clamshell = clamshell
            deadline = duration.map { now.addingTimeInterval($0) }
            floorTripped = false
            effects.append(.acquire(currentSpec))
            if clamshell { effects.append(.armClamshell(deadline: deadline)) }
            return effects

        case .stop:
            guard isActive else { return [] }
            return endSession(reason: .user)

        case .tick:
            guard isActive, let deadline, now >= deadline else { return [] }
            return endSession(reason: .expired)

        case let .power(status):
            guard isActive, !floorTripped, status.onBattery, floorPercent > 0,
                  let percent = status.percent, percent <= floorPercent else { return [] }
            floorTripped = true
            var effects = endSession(reason: .batteryFloor)
            effects.append(.notifyFloorStop(percent: percent))
            return effects

        case let .setDisplayAwake(value):
            displayAwake = value
            guard isActive else { return [] }    // off: store only, applies on next start
            return [.acquire(currentSpec)]

        case let .setFloor(value):
            floorPercent = value                 // evaluated on the next power event
            return []

        case .clamshellArmFailed:
            guard isActive, clamshell else { return [] }
            return endSession(reason: .user)     // never run a half-armed clamshell session
        }
    }

    /// Release the live session and return to `off`. Emits `disarmClamshell` first
    /// when the ending session held the clamshell flag.
    private mutating func endSession(reason: KeepAwakeStopReason) -> [PowerEffect] {
        var effects: [PowerEffect] = []
        if clamshell { effects.append(.disarmClamshell) }
        effects.append(.release(reason))
        isActive = false
        clamshell = false
        deadline = nil
        return effects
    }
}
