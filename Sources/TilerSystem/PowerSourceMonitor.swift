import Foundation
import IOKit.ps
import TilerCore

/// Battery/AC state via IOPowerSources (power spec). Event-driven — no polling, no
/// root: `IOPSNotificationCreateRunLoopSource` fires `onChange` on the main run loop
/// whenever the power source or charge changes. `read()` is also usable standalone
/// (launch-time snapshot). Unlike the IOPMLib CFSTR macros, the IOPS key/value
/// constants DO import into Swift, so they are used directly.
@MainActor public final class PowerSourceMonitor {
    public var onChange: ((PowerStatus) -> Void)?
    private var runLoopSource: CFRunLoopSource?

    public init() {}

    public func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let unmanaged = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(ctx).takeUnretainedValue()
            // Registered on the main run loop, so the callback fires on the main thread.
            MainActor.assumeIsolated {
                monitor.onChange?(PowerSourceMonitor.read())
            }
        }, context) else {
            NSLog("Tiler: power-source notifier unavailable")
            return
        }
        let source = unmanaged.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
        NSLog("Tiler: power-source monitor started")
    }

    public static func read() -> PowerStatus {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = list.first,
              let desc = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any]
        else {
            return PowerStatus(percent: nil, onBattery: false)   // desktop / no battery
        }
        let percent = desc[kIOPSCurrentCapacityKey] as? Int
        let onBattery = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue
        return PowerStatus(percent: percent, onBattery: onBattery)
    }
}
