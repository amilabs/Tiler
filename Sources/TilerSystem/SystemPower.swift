import Foundation
import IOKit

/// Small IORegistry reads for diagnostics (power spec debug logging). In-process,
/// no subprocess, no root.
public enum SystemPower {
    /// Whether the built-in lid is currently closed (`AppleClamshellState` on
    /// IOPMrootDomain). Absent key (desktops) reads as false.
    public static func lidClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString,
                                                    kCFAllocatorDefault, 0)
        return (value?.takeRetainedValue() as? Bool) ?? false
    }
}
