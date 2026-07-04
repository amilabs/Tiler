import CMultitouchSupport
import Foundation
import TilerCore

/// Thin wrapper over the private MultitouchSupport framework: subscribes to raw
/// contact frames and delivers normalized `TouchFrame`s on a serial queue.
/// Loading is dlopen/dlsym-based — the framework binary lives in the dyld shared
/// cache (design.md §1 probe findings). Push-based: zero CPU while untouched.
/// @unchecked Sendable: mutable state (devices/running) is only touched from
/// start()/stop() on the owner's actor; the C callback reads only immutable members.
final class TouchStream: @unchecked Sendable {
    typealias CreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>?
    typealias RegisterCallbackFn = @convention(c) (TLMTDeviceRef, TLMTContactCallback?) -> Void
    typealias StartFn = @convention(c) (TLMTDeviceRef, Int32) -> Void
    typealias StopFn = @convention(c) (TLMTDeviceRef) -> Void

    enum StreamError: Error, CustomStringConvertible {
        case frameworkUnavailable(String)
        case noDevices

        var description: String {
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

    private let createList: CreateListFn
    private let registerCallback: RegisterCallbackFn
    private let startDevice: StartFn
    private let stopDevice: StopFn

    /// `handler` is called on the stream's serial queue for every contact frame.
    init(handler: @escaping @Sendable (TouchFrame) -> Void) throws {
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
    }

    func start() throws {
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
    }

    func stop() {
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

    // MARK: - C callback plumbing

    private static let contactCallback: TLMTContactCallback = { device, touches, numTouches, timestamp, _ in
        guard let stream = TouchStream.current else { return 0 }
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
