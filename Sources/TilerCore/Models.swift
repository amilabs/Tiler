/// Raw multitouch contact state, mirroring the private MultitouchSupport values.
/// Only `making` and `touching` count as physically active for gesture purposes.
public enum ContactState: Int, Codable, Sendable, Equatable {
    case notTracking = 0
    case starting = 1
    case hovering = 2
    case making = 3
    case touching = 4
    case breaking = 5
    case lingering = 6
    case leaving = 7
}

/// One trackpad contact in one frame.
/// Coordinates are normalized to 0...1 with the origin at the bottom-left of the pad
/// (MultitouchSupport convention): x grows rightward, y grows upward.
/// `size` is the contact's zTotal (finger ≈ 0.2...1.5, palm noticeably larger, stale ≈ 0).
public struct Contact: Codable, Sendable, Equatable {
    public var deviceID: UInt64
    public var fingerID: Int32
    public var state: ContactState
    public var size: Double
    public var x: Double
    public var y: Double

    public init(deviceID: UInt64, fingerID: Int32, state: ContactState,
                size: Double, x: Double, y: Double) {
        self.deviceID = deviceID
        self.fingerID = fingerID
        self.state = state
        self.size = size
        self.x = x
        self.y = y
    }
}

/// One multitouch callback frame. `timestamp` is in seconds (monotonic device clock).
public struct TouchFrame: Codable, Sendable, Equatable {
    public var timestamp: Double
    public var contacts: [Contact]

    public init(timestamp: Double, contacts: [Contact]) {
        self.timestamp = timestamp
        self.contacts = contacts
    }
}

public enum GestureDirection: String, Codable, Sendable, Equatable {
    case left, right, up
}

/// The single output of a confirmed gesture. Swipe-down and Cmd+up produce no action.
public struct GestureAction: Codable, Sendable, Equatable {
    public var direction: GestureDirection
    public var nextDisplay: Bool

    public init(direction: GestureDirection, nextDisplay: Bool) {
        self.direction = direction
        self.nextDisplay = nextDisplay
    }
}
