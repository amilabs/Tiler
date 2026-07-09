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

    /// Every process-held sleep-blocking assertion (`pmset -g assertions`) as trimmed
    /// one-line summaries — so the diagnostic log shows exactly what is keeping the Mac
    /// awake (incl. non-Tiler holders like coreaudiod), no manual `pmset` needed.
    public static func sleepBlockers() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do { try process.run() } catch { return [] }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        return text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { line in
            line.hasPrefix("pid ")
                && (line.contains("PreventUserIdleSystemSleep")
                    || line.contains("PreventSystemSleep")
                    || line.contains("PreventUserIdleDisplaySleep"))
        }
    }
}
