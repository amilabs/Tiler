import Foundation

/// Task 1.4 probe: verifies the private MultitouchSupport framework is loadable on this
/// macOS version, devices enumerate, and a contact-frame callback registers without
/// crashing or requiring extra TCC. Real touch data needs a human finger (gate 3.1).
enum MTProbe {
    typealias MTDeviceRef = UnsafeMutableRawPointer
    // int callback(MTDeviceRef, MTTouch*, int numTouches, double timestamp, int frame)
    typealias MTContactCallback = @convention(c) (
        MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32
    ) -> Int32
    typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>?
    typealias MTRegisterContactFrameCallbackFn = @convention(c) (MTDeviceRef, MTContactCallback?) -> Void
    typealias MTDeviceStartFn = @convention(c) (MTDeviceRef, Int32) -> Void
    typealias MTDeviceStopFn = @convention(c) (MTDeviceRef) -> Void

    nonisolated(unsafe) static var framesReceived = 0

    static func run(seconds: UInt32) {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
            RTLD_NOW
        ) else {
            let err = dlerror().map { String(cString: $0) } ?? "unknown"
            print("MT-PROBE: dlopen FAILED: \(err)")
            exit(1)
        }
        print("MT-PROBE: dlopen OK")

        func sym<T>(_ name: String, as type: T.Type) -> T? {
            guard let p = dlsym(handle, name) else {
                print("MT-PROBE: symbol \(name) MISSING")
                return nil
            }
            return unsafeBitCast(p, to: T.self)
        }

        guard
            let createList = sym("MTDeviceCreateList", as: MTDeviceCreateListFn.self),
            let registerCB = sym("MTRegisterContactFrameCallback", as: MTRegisterContactFrameCallbackFn.self),
            let start = sym("MTDeviceStart", as: MTDeviceStartFn.self),
            let stop = sym("MTDeviceStop", as: MTDeviceStopFn.self)
        else { exit(1) }
        print("MT-PROBE: all symbols resolved")

        guard let listUnmanaged = createList() else {
            print("MT-PROBE: MTDeviceCreateList returned nil")
            exit(1)
        }
        let list = listUnmanaged.takeRetainedValue() as [AnyObject]
        print("MT-PROBE: devices found: \(list.count)")
        guard !list.isEmpty else {
            print("MT-PROBE: no multitouch devices — cannot continue")
            exit(1)
        }

        let callback: MTContactCallback = { _, _, numTouches, _, _ in
            MTProbe.framesReceived += 1
            if MTProbe.framesReceived <= 3 {
                print("MT-PROBE: frame with \(numTouches) touches")
            }
            return 0
        }

        var started: [MTDeviceRef] = []
        for dev in list {
            let ref = MTDeviceRef(Unmanaged.passUnretained(dev).toOpaque())
            registerCB(ref, callback)
            start(ref, 0)
            started.append(ref)
        }
        print("MT-PROBE: callbacks registered and devices started (no crash, no TCC prompt = OK)")
        print("MT-PROBE: listening \(seconds)s (frames arrive only on physical touch)...")
        Thread.sleep(forTimeInterval: TimeInterval(seconds))

        for ref in started { stop(ref) }
        print("MT-PROBE: frames received: \(framesReceived)")
        print("MT-PROBE: RESULT OK — registration path works on this macOS")
        exit(0)
    }
}
