import CMultitouchSupport
import Foundation
import TilerCore

/// Thin wrapper over the private MultitouchSupport framework: subscribes to raw
/// contact frames and delivers normalized `TouchFrame`s on a serial queue.
/// Loading is dlopen/dlsym-based — the framework binary lives in the dyld shared
/// cache (design.md §1 probe findings). Push-based: zero CPU while untouched.
/// @unchecked Sendable: mutable state (devices/running) is only touched from
/// start()/stop() on the owner's actor; the C callback reads only immutable members.
public final class TouchStream: @unchecked Sendable {
    typealias CreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>?
    typealias RegisterCallbackFn = @convention(c) (TLMTDeviceRef, TLMTContactCallback?) -> Void
    typealias StartFn = @convention(c) (TLMTDeviceRef, Int32) -> Void
    typealias StopFn = @convention(c) (TLMTDeviceRef) -> Void
    typealias GetDeviceIDFn = @convention(c) (TLMTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32

    public enum StreamError: Error, CustomStringConvertible {
        case frameworkUnavailable(String)
        case noDevices

        public var description: String {
            switch self {
            case .frameworkUnavailable(let detail): "MultitouchSupport unavailable: \(detail)"
            case .noDevices: "no multitouch devices found"
            }
        }
    }

    /// The single live instance the C callback forwards into.
    private nonisolated(unsafe) static var current: TouchStream?

    private let queue = DispatchQueue(label: "pro.amilabs.tiler.touchstream", qos: .userInteractive)
    private let handler: @Sendable (TouchFrame) -> Void
    private var devices: [TLMTDeviceRef] = []
    private var deviceList: CFMutableArray?
    private var running = false

    // Liveness/identity state for the stream guardian. Written from the C callback's
    // MultitouchSupport thread and start(); read from the main actor — lock-guarded.
    private let stateLock = NSLock()
    private var lastFrameTime: CFAbsoluteTime?
    private var startedTime: CFAbsoluteTime?
    private var attachedIDs: [UInt64] = []

    private let createList: CreateListFn
    private let registerCallback: RegisterCallbackFn
    private let startDevice: StartFn
    private let stopDevice: StopFn
    private let getDeviceID: GetDeviceIDFn?   // optional: absent symbol degrades drift to count-only

    /// `handler` is called on the stream's serial queue for every contact frame.
    public init(handler: @escaping @Sendable (TouchFrame) -> Void) throws {
        self.handler = handler

        guard let lib = dlopen(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
            RTLD_NOW
        ) else {
            throw StreamError.frameworkUnavailable(dlerror().map { String(cString: $0) } ?? "dlopen failed")
        }
        func sym<T>(_ name: String, _ type: T.Type) throws -> T {
            guard let p = dlsym(lib, name) else {
                throw StreamError.frameworkUnavailable("missing symbol \(name)")
            }
            return unsafeBitCast(p, to: T.self)
        }
        createList = try sym("MTDeviceCreateList", CreateListFn.self)
        registerCallback = try sym("MTRegisterContactFrameCallback", RegisterCallbackFn.self)
        startDevice = try sym("MTDeviceStart", StartFn.self)
        stopDevice = try sym("MTDeviceStop", StopFn.self)
        getDeviceID = dlsym(lib, "MTDeviceGetDeviceID").map { unsafeBitCast($0, to: GetDeviceIDFn.self) }
    }

    public func start() throws {
        guard !running else { return }
        guard let listUnmanaged = createList() else { throw StreamError.noDevices }
        let list = listUnmanaged.takeRetainedValue()
        deviceList = list // keep devices alive while running
        let count = CFArrayGetCount(list)
        guard count > 0 else { throw StreamError.noDevices }

        devices = (0..<count).map { i in
            TLMTDeviceRef(mutating: CFArrayGetValueAtIndex(list, i)!)
        }
        TouchStream.current = self
        for dev in devices {
            registerCallback(dev, TouchStream.contactCallback)
            startDevice(dev, 0)
        }
        running = true

        let signature = signature(of: devices)
        stateLock.lock()
        attachedIDs = signature
        startedTime = CFAbsoluteTimeGetCurrent()
        lastFrameTime = nil
        stateLock.unlock()
    }

    public func stop() {
        guard running else { return }
        for dev in devices {
            stopDevice(dev)
            registerCallback(dev, nil)
        }
        devices = []
        deviceList = nil
        running = false
        TouchStream.current = nil
    }

    deinit {
        stop()
    }

    // MARK: - Guardian support (identity + liveness)

    /// Device signature: sorted real device IDs when `MTDeviceGetDeviceID` is
    /// available, else the degenerate `[count]` (drift then means count change only).
    private func signature(of devs: [TLMTDeviceRef]) -> [UInt64] {
        guard let getDeviceID else { return [UInt64(devs.count)] }
        return devs.compactMap { dev in
            var id: UInt64 = 0
            return getDeviceID(dev, &id) == 0 ? id : nil
        }.sorted()
    }

    /// The signature captured by the last successful start().
    public var attachedSignature: [UInt64] {
        stateLock.lock(); defer { stateLock.unlock() }
        return attachedIDs
    }

    /// Fresh enumeration, same encoding as `attachedSignature`; nil when the device
    /// list cannot be built (no information — the policy never treats nil as drift).
    public func currentSignature() -> [UInt64]? {
        guard let listUnmanaged = createList() else { return nil }
        let list = listUnmanaged.takeRetainedValue()
        let count = CFArrayGetCount(list)
        let devs = (0..<count).map { i in
            TLMTDeviceRef(mutating: CFArrayGetValueAtIndex(list, i)!)
        }
        return signature(of: devs)
    }

    /// Seconds since the stream last delivered a contact frame — counted from the
    /// last start() when no frame arrived yet, so a fresh stream is never
    /// instantly "long silent". Nil before the first start().
    public func silentSeconds(now: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> Double? {
        stateLock.lock(); defer { stateLock.unlock() }
        guard let reference = lastFrameTime ?? startedTime else { return nil }
        return max(0, now - reference)
    }

    private func noteFrame() {
        stateLock.lock()
        lastFrameTime = CFAbsoluteTimeGetCurrent()
        stateLock.unlock()
    }

    // MARK: - C callback plumbing

    private static let contactCallback: TLMTContactCallback = { device, touches, numTouches, timestamp, _ in
        guard let stream = TouchStream.current else { return 0 }
        stream.noteFrame()
        let deviceID = UInt64(UInt(bitPattern: device))
        var contacts: [Contact] = []
        if let touches, numTouches > 0 {
            contacts.reserveCapacity(Int(numTouches))
            for i in 0..<Int(numTouches) {
                let raw = touches[i]
                contacts.append(Contact(
                    deviceID: deviceID,
                    fingerID: raw.identifier,
                    state: ContactState(rawValue: Int(raw.state)) ?? .notTracking,
                    size: Double(raw.zTotal),
                    x: Double(raw.normalized.position.x),
                    y: Double(raw.normalized.position.y)
                ))
            }
        }
        let frame = TouchFrame(timestamp: timestamp, contacts: contacts)
        stream.queue.async { stream.handler(frame) }
        return 0
    }
}
