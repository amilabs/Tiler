// clamshell_spike.swift — add-power-control, task 0.2 (gate 0.2 evidence tool)
//
// Question under test: does macOS 26 keep the system running across a lid close
// while a process holds PreventSystemSleep (+AppliesToLimitedPower, for battery)
// and PreventUserIdleSystemSleep assertions — the Amphetamine-style, no-root path?
//
// Usage (run from this directory; any terminal):
//   swift clamshell_spike.swift selftest   # no lid action: create → verify → release
//   swift clamshell_spike.swift battery    # unplugged: close lid ~2 min, then open
//   swift clamshell_spike.swift ac         # plugged in: close lid ~2 min, then open
//   sudo pmset -a disablesleep 1 && swift clamshell_spike.swift fallback
//                                          # unplugged: the root fallback path;
//                                          # afterwards: sudo pmset -a disablesleep 0
//
// The script detects the lid via AppleClamshellState, heartbeats every 2 s while
// closed, and infers sleep from wall-clock gaps (a frozen process cannot beat).
// Verdict + full evidence land in ./spike-<phase>-<time>.log. Assertions are
// process-scoped: any exit (incl. Ctrl-C / crash) releases them by construction.
//
// NOTE for the future implementation: IOPMLib's k*Key constants are CFSTR macros
// and are NOT imported into Swift — the literal strings below ("AssertType",
// "AppliesToLimitedPower", …) are the API contract.
//
// FINDINGS (selftest probes, macOS 26.5, 2026-07-08):
//   - PreventUserIdleSystemSleep (plain)      → allowed for a user process
//   - PreventSystemSleep (plain)              → allowed (parity with `caffeinate -s`;
//                                               documented semantics: honored on AC)
//   - + "AppliesToLimitedPower" property      → kIOReturnNotPrivileged (0xe00002c1)
//   - + "AppliesOnLidClose" property          → kIOReturnNotPrivileged (0xe00002c1)
// i.e. macOS 26 gates the battery/lid-close *extender properties* behind
// privileges while the base assertion types stay public. Expected consequence:
// lid-closed-awake without root can work on AC at best; battery+lid-closed needs
// the root path (`pmset disablesleep 1`) — measured by the 'fallback' phase.
// A root process could hold the privileged properties directly (model-B note).

import Foundation
import IOKit
import IOKit.pwr_mgt

// ---------- logging ----------

let phase = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "adhoc"
let fileStamp: String = {
    let f = DateFormatter(); f.dateFormat = "HHmmss"; return f.string(from: Date())
}()
let logURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("spike-\(phase)-\(fileStamp).log")
FileManager.default.createFile(atPath: logURL.path, contents: nil)
let logHandle = try! FileHandle(forWritingTo: logURL)
let clock: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
}()

func log(_ s: String, echo: Bool = true) {
    let line = "[\(clock.string(from: Date()))] \(s)\n"
    logHandle.write(line.data(using: .utf8)!)
    if echo { print(line, terminator: "") }
}

func shell(_ cmd: String) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-c", cmd]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return "shell error: \(error)" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

// ---------- assertions ----------

var held: [(label: String, id: IOPMAssertionID)] = []

func hold(_ props: [String: Any], label: String) -> Bool {
    var id = IOPMAssertionID(0)
    let r = IOPMAssertionCreateWithProperties(props as CFDictionary, &id)
    if r == kIOReturnSuccess {
        held.append((label, id))
        log("assertion held: \(label) (id \(id))")
        return true
    }
    log("FAILED to hold \(label): IOReturn 0x\(String(UInt32(bitPattern: r), radix: 16))")
    return false
}

func releaseAll() {
    for a in held {
        IOPMAssertionRelease(a.id)
        log("assertion released: \(a.label)")
    }
    held.removeAll()
}

// ---------- sensors ----------

let rootDomain: io_registry_entry_t =
    IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))

/// true = closed, false = open, nil = no clamshell (desktop) / read failure
func clamshellClosed() -> Bool? {
    guard rootDomain != 0,
          let cf = IORegistryEntryCreateCFProperty(
              rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
    else { return nil }
    return (cf.takeRetainedValue() as? NSNumber)?.boolValue
}

// ---------- run ----------

log("clamshell spike — phase '\(phase)' — log: \(logURL.lastPathComponent)")
let battLine = shell("pmset -g batt").trimmingCharacters(in: .whitespacesAndNewlines)
log("power source: \(battLine.replacingOccurrences(of: "\n", with: " | "))", echo: false)
let onAC = battLine.contains("AC Power")

if phase == "battery" && onAC {
    log("ABORT: phase 'battery' but the Mac is on AC Power — unplug and rerun.")
    exit(2)
}
if phase == "ac" && !onAC {
    log("ABORT: phase 'ac' but the Mac is on battery — plug in and rerun.")
    exit(2)
}
if phase == "fallback" {
    if onAC {
        log("ABORT: phase 'fallback' should run on battery (that's the case that needs it) — unplug and rerun.")
        exit(2)
    }
    let flags = shell("pmset -g")
    if flags.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) == nil {
        log("ABORT: phase 'fallback' needs the flag first:  sudo pmset -a disablesleep 1")
        exit(2)
    }
    log("SleepDisabled=1 confirmed — measuring the pmset disablesleep fallback path.")
}

let okIdle = hold([
    "AssertType": "PreventUserIdleSystemSleep",
    "AssertName": "Tiler clamshell spike (idle)",
    "AssertLevel": 255,
], label: "PreventUserIdleSystemSleep (base)")

let okLidClose = hold([
    "AssertType": "PreventUserIdleSystemSleep",
    "AssertName": "Tiler clamshell spike (lid-close)",
    "AssertLevel": 255,
    "AppliesOnLidClose": NSNumber(value: true),
], label: "PreventUserIdleSystemSleep+AppliesOnLidClose")

// Both expected to fail as a normal user (privilege probe — logged, best-effort):
let okSystemPlain = hold([
    "AssertType": "PreventSystemSleep",
    "AssertName": "Tiler clamshell spike (system plain)",
    "AssertLevel": 255,
], label: "PreventSystemSleep (plain, privilege probe)")
let okSystemLimited = hold([
    "AssertType": "PreventSystemSleep",
    "AssertName": "Tiler clamshell spike (system limited)",
    "AssertLevel": 255,
    "AppliesToLimitedPower": NSNumber(value: true),
], label: "PreventSystemSleep+AppliesToLimitedPower (privilege probe)")

let dump = shell("pmset -g assertions")
log("--- pmset -g assertions after create ---\n\(dump)--- end ---", echo: false)
let visible = dump.contains("Tiler clamshell spike")
log(visible ? "pmset lists the spike assertions ✓"
            : "WARNING: pmset does NOT list the spike assertions")
log(dump.contains("AppliesOnLidClose")
    ? "pmset shows the AppliesOnLidClose property ✓"
    : "note: AppliesOnLidClose not visible in pmset dump (may still be honored — lid test decides)")

if phase == "selftest" {
    releaseAll()
    let after = shell("pmset -g assertions")
    let gone = !after.contains("Tiler clamshell spike")
    log("--- pmset -g assertions after release ---\n\(after)--- end ---", echo: false)
    let pass = okIdle && okSystemPlain && visible && gone
    log("probe summary: idle=\(okIdle) systemPlain=\(okSystemPlain) "
        + "lidCloseProp=\(okLidClose) limitedPowerProp=\(okSystemLimited) "
        + "(the two properties are expected-privileged on macOS 26)")
    log(pass ? "selftest PASS (public assertions held + listed + released cleanly)"
             : "selftest FAIL (idle=\(okIdle) systemPlain=\(okSystemPlain) listed=\(visible) releasedClean=\(gone))")
    exit(pass ? 0 : 1)
}

guard okIdle && okSystemPlain else {
    log("ABORT: could not hold the public assertions.")
    releaseAll()
    exit(1)
}
guard clamshellClosed() != nil else {
    log("ABORT: AppleClamshellState unavailable — is this a desktop Mac?")
    releaseAll()
    exit(1)
}

let closeTimeout = Double(ProcessInfo.processInfo.environment["SPIKE_CLOSE_TIMEOUT"] ?? "") ?? 90
let minClosedForVerdict: Double = 60

log("READY. Close the lid now, keep it closed for ~2 minutes, then open it.")
log("(the script waits up to \(Int(closeTimeout)) s for the close, finishes itself after reopen)")

let waitStart = Date()
while clamshellClosed() != true {
    if Date().timeIntervalSince(waitStart) > closeTimeout {
        log("VERDICT: NOT-RUN — lid was not closed within \(Int(closeTimeout)) s.")
        releaseAll()
        exit(2)
    }
    Thread.sleep(forTimeInterval: 0.5)
}

let closedAt = Date()
log("lid CLOSED — heartbeating every 2 s (gaps = sleep) …")
var lastBeat = Date()
var maxGap: Double = 0
var gaps: [String] = []

while clamshellClosed() == true {
    Thread.sleep(forTimeInterval: 2)
    let now = Date()
    let gap = now.timeIntervalSince(lastBeat)
    if gap > 5 {
        gaps.append(String(format: "gap of %.1f s ending %@", gap, clock.string(from: now)))
    }
    if gap > maxGap { maxGap = gap }
    lastBeat = now
    log(String(format: "beat gap=%.1f s", gap), echo: false)
}

let openedAt = Date()
let closedFor = openedAt.timeIntervalSince(closedAt)
log(String(format: "lid OPENED — closed for %.0f s, max heartbeat gap %.1f s", closedFor, maxGap))

if closedFor < minClosedForVerdict {
    log("VERDICT: TOO-SHORT — keep the lid closed for at least \(Int(minClosedForVerdict)) s and rerun.")
} else if maxGap < 8 {
    log(String(format: "VERDICT: STAYED AWAKE (%@) — lid closed %.0f s, max gap %.1f s.",
               phase.uppercased(), closedFor, maxGap))
} else if maxGap >= 25 {
    log(String(format: "VERDICT: SLEPT (%@) — a %.1f s heartbeat gap means a sleep episode.",
               phase.uppercased(), maxGap))
} else {
    log(String(format: "VERDICT: AMBIGUOUS (%@) — max gap %.1f s; see gaps; consider a rerun.",
               phase.uppercased(), maxGap))
}
for g in gaps { log("  " + g) }

let pmLog = shell(
    "pmset -g log | grep -E 'Entering Sleep|Wake from|DarkWake|Clamshell|Maintenance' | tail -50")
log("--- pmset -g log excerpt (sleep/wake around the test) ---\n\(pmLog)--- end ---", echo: false)

releaseAll()
if phase == "fallback" {
    let flags = shell("pmset -g | grep -i sleepdisabled").trimmingCharacters(in: .whitespacesAndNewlines)
    log("flag state now: \(flags)")
    log("IMPORTANT — restore normal sleep NOW:  sudo pmset -a disablesleep 0")
}
log("done — evidence: \(logURL.path)")
