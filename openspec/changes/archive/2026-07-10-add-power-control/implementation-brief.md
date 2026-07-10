# add-power-control — Implementation Brief (Tiler v0.3.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:executing-plans`
> to implement this plan task-by-task in this session (it was written for a fresh
> session with zero context). Steps use checkbox (`- [ ]`) syntax; mirror your
> progress into `tasks.md` in this folder (owner mandate: checkboxes update AS you
> work, not after). Task numbers here match `tasks.md` phases 1–4.

**Goal:** caffeinator-class power control in Tiler: Keep Awake sessions
(indefinite/timed), battery floor auto-stop, lid-closed keep-awake via a
single-prompt root path, and a persistent battery-side Deep Sleep (hibernate)
profile.

**Architecture:** pure decision core (`PowerPolicy` FSM + `PmsetCustomParser` in
TilerCore, fully TDD) driven by thin system adapters in TilerSystem (IOPM
assertions, IOPS battery events, osascript admin shell, sentinel-watchdog governor,
pmset profile controller); AppKit/SwiftUI wiring in the Tiler target. No new
dependencies, no new processes except the transient root watchdog.

**Tech Stack:** Swift 6.3 SwiftPM (macOS 26 only), AppKit + SwiftUI, IOKit
(`IOPMAssertionCreateWithProperties`, IOPowerSources), UserNotifications,
`osascript … with administrator privileges`.

## Global Constraints

- Read `openspec/project.md` and this change's `proposal.md` / `design.md` /
  `specs/` first. Spec scenarios = required tests / verifications.
- Bundle id `pro.amilabs.tilerx` and identity `Apple Development:
  alexnsk@gmail.com (PHYV972T38)` — never change (TCC-load-bearing).
- `swift build && swift test` green before every commit that claims a task done.
- TDD for everything in TilerCore and for every pure helper (`armCommand`,
  `appleScriptLiteral`, parsers). System adapters get NSLog state lines + the
  acceptance script instead of unit tests.
- Sentinel path constant: `/tmp/pro.amilabs.tilerx.clamshell.sentinel`.
- Assertion names all start with `"Tiler Keep Awake"` (acceptance greps rely on it).
- UI copy in English. Chat with the owner in Russian. Shell commands you give the
  owner must contain NO `#` comments (his zsh chokes: no `interactivecomments`).
- The owner's daily user has NO sudo. Anything privileged goes through the admin
  dialog (`osascript … with administrator privileges`); the owner enters the
  admin user `ami` there. Never call `sudo` in app code or owner instructions.
- Durations: 10 min, 30 min, 1 h, 2 h, 5 h, 10 h, 24 h. Floor: Off/30/20/10 %,
  default 20. Display-awake default off. Clamshell option resets every session.
- [USER GATE] tasks are hard STOP points: post the batched ask (Russian), wait.
- macOS facts already measured (do not re-litigate): user processes CAN hold
  `PreventUserIdleSystemSleep`, `PreventUserIdleDisplaySleep`, plain
  `PreventSystemSleep` (effective on AC only); the properties
  `AppliesToLimitedPower` / `AppliesOnLidClose` are privileged
  (kIOReturnNotPrivileged); lid-closed on battery works only via
  `pmset -a disablesleep 1` (spike logs in `spike/`). IOPMLib `k…` string
  constants are CFSTR macros — NOT imported into Swift; use literal strings
  `"AssertType"`, `"AssertName"`, `"AssertLevel"`.

---

### Task 1.1: `PowerPolicy` FSM (TilerCore, TDD)

**Files:**
- Create: `Sources/TilerCore/PowerPolicy.swift`
- Test: `Tests/TilerCoreTests/PowerPolicyTests.swift`

**Interfaces (Produces — later tasks import these exact names):**

```swift
public struct AssertionSpec: Equatable, Sendable {
    public var displayAwake: Bool
    public var systemSleepBlock: Bool
    public init(displayAwake: Bool, systemSleepBlock: Bool)
}
public enum KeepAwakeStopReason: String, Equatable, Sendable {
    case user, expired, batteryFloor
}
public struct PowerStatus: Equatable, Sendable {
    public var percent: Int?
    public var onBattery: Bool
    public init(percent: Int?, onBattery: Bool)
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
    public private(set) var isActive: Bool
    public private(set) var clamshell: Bool
    public private(set) var deadline: Date?
    public init(displayAwake: Bool, floorPercent: Int)
    public mutating func handle(_ command: PowerCommand, now: Date) -> [PowerEffect]
    public func remaining(now: Date) -> TimeInterval?   // nil when off/indefinite
}
```

Semantics (each bullet = at least one test):
- `start` while off → `[.acquire(spec)]`, plus `.armClamshell(deadline:)` appended
  when `clamshell: true`; `deadline = now + duration` when duration != nil.
  `spec.systemSleepBlock == clamshell`; `spec.displayAwake` mirrors the setting.
- `start` while active → replacement: `[.disarmClamshell (only if old was
  clamshell), .release(.user), .acquire(newSpec), (.armClamshell if new clamshell)]`.
- `stop` while active → `[.disarmClamshell?, .release(.user)]`; while off → `[]`.
- `tick` past deadline → `[.disarmClamshell?, .release(.expired)]`; before → `[]`.
- `power(status)` while active, `onBattery`, floor > 0, `percent <= floor` →
  `[.disarmClamshell?, .release(.batteryFloor), .notifyFloorStop(percent)]`.
  Same percent on AC → `[]` (test). After a floor stop, further `power` /
  `tick` → `[]` (no auto-restart — test).
- `setDisplayAwake` while active → `[.acquire(updatedSpec)]`; while off → `[]`
  (just stores).
- `clamshellArmFailed` while active-clamshell → `[.disarmClamshell,
  .release(.user)]` (session must not run half-armed); otherwise `[]`.
- `percent == nil` (desktop) never triggers the floor.

**Steps:**
- [ ] Write `PowerPolicyTests` covering every bullet above (12–15 focused tests,
      inject `now` via `Date(timeIntervalSinceReferenceDate:)` fixtures).
- [ ] `swift test --filter PowerPolicyTests` → all FAIL (type not defined).
- [ ] Implement `PowerPolicy` (private `floorTripped` flag; keep it a value type).
- [ ] `swift test` → green. Commit: `feat(core): PowerPolicy session FSM (TDD)`.

### Task 1.2: SettingsStore power keys

**Files:**
- Modify: `Sources/TilerSystem/SettingsStore.swift`
- Test: `Tests/TilerIntegrationTests/SettingsStoreTests.swift` (existing pattern:
  injectable `UserDefaults` suite)

**Produces:** `keepDisplayAwake: Bool` (default false), `batteryFloorPercent: Int`
(default 20; 0 = off), `deepSleepOnBattery: Bool` (default false; *stored intent*,
reconciled at launch), `powerSnapshot: [String: String]?` (JSON-encoded like
`tunablesOverride`). Each fires the existing `onChange` except `powerSnapshot`
(bookkeeping, like `hasSeenGuide`).

**Steps:**
- [ ] Tests: round-trip each key through a scratch suite; defaults asserted.
- [ ] Run → FAIL; implement following the existing `didSet` pattern exactly.
- [ ] `swift test` green. Commit: `feat(system): power settings keys`.

### Task 1.3: `AwakeController` + `PowerSourceMonitor` + wiring

**Files:**
- Create: `Sources/TilerSystem/AwakeController.swift`,
  `Sources/TilerSystem/PowerSourceMonitor.swift`
- Modify: `Sources/Tiler/AppDelegate.swift` (fields + `setUpPower()` called from
  `applicationDidFinishLaunching`, before `handleDebugWindowArgs()`)

**Produces:**

```swift
@MainActor public final class AwakeController {
    public init()
    public func apply(_ spec: AssertionSpec?)     // nil releases everything
    public var heldSummary: String                // "idle+display+system" | "none"
}
@MainActor public final class PowerSourceMonitor {
    public init()
    public var onChange: ((PowerStatus) -> Void)?
    public func start()
    public static func read() -> PowerStatus
}
```

`AwakeController.apply` diffs current vs wanted and creates/releases three named
assertions via `IOPMAssertionCreateWithProperties` with literal-string properties:

```swift
private func create(type: String, name: String) -> IOPMAssertionID? {
    var id = IOPMAssertionID(0)
    let props: [String: Any] = [
        "AssertType": type,
        "AssertName": name,
        "AssertLevel": 255,
    ]
    guard IOPMAssertionCreateWithProperties(props as CFDictionary, &id)
        == kIOReturnSuccess else {
        NSLog("Tiler: power assertion FAILED: %@", type)
        return nil
    }
    return id
}
// idle   → "PreventUserIdleSystemSleep",  "Tiler Keep Awake (idle)"    — always
// display→ "PreventUserIdleDisplaySleep", "Tiler Keep Awake (display)" — spec.displayAwake
// system → "PreventSystemSleep",          "Tiler Keep Awake (system)"  — spec.systemSleepBlock
```

Log every transition: `NSLog("Tiler: keep-awake %@", heldSummary)`.

`PowerSourceMonitor`: `IOPSNotificationCreateRunLoopSource` on the main run loop;
`read()` uses `IOPSCopyPowerSourcesInfo`/`IOPSCopyPowerSourcesList`/
`IOPSGetPowerSourceDescription`, extracting `kIOPSCurrentCapacityKey` (Int) and
`kIOPSPowerSourceStateKey == kIOPSBatteryPowerValue` → `onBattery` (these IOPS
constants DO import into Swift — unlike the IOPMLib CFSTR macros). No sources
(desktop) → `PowerStatus(percent: nil, onBattery: false)`.

AppDelegate wiring (the only stateful glue; keep it ~40 lines):

```swift
private var powerPolicy = PowerPolicy(displayAwake: false, floorPercent: 20)
private var awake: AwakeController?
private var powerMonitor: PowerSourceMonitor?
private var powerTick: DispatchSourceTimer?

private func setUpPower() {
    powerPolicy = PowerPolicy(displayAwake: settings.keepDisplayAwake,
                              floorPercent: settings.batteryFloorPercent)
    awake = AwakeController()
    let monitor = PowerSourceMonitor()
    monitor.onChange = { [weak self] status in self?.powerApply(.power(status)) }
    monitor.start()
    powerMonitor = monitor
}

func powerApply(_ command: PowerCommand) {
    for effect in powerPolicy.handle(command, now: Date()) { perform(effect) }
    refreshPowerTick()   // 5 s DispatchSourceTimer alive only while isActive
    updateStatusGlyph()  // session indicator (task 2.2)
}
```

`perform(_:)` switches: `.acquire` → `awake?.apply(spec)`; `.release` →
`awake?.apply(nil)` + NSLog reason; `.armClamshell`/`.disarmClamshell` → governor
(task 1.5 — until then, NSLog stub); `.notifyFloorStop` → notifier (task 1.4 —
NSLog stub until then). Also extend `setUpSettingsWiring`'s `onChange` closure:
feed `.setDisplayAwake(store.keepDisplayAwake)` and
`.setFloor(store.batteryFloorPercent)` through `powerApply`.

Debug args in `handleDebugWindowArgs()` (house precedent — the acceptance script
depends on these exact flags):

```swift
if let i = args.firstIndex(of: "--power-start"), args.indices.contains(i + 1) {
    let d: TimeInterval? = args[i + 1] == "inf" ? nil
        : Double(args[i + 1].dropLast()).map { args[i + 1].hasSuffix("h") ? $0 * 3600 : $0 * 60 }
    powerApply(.start(clamshell: false, duration: d))   // "30m", "2h", "inf"
}
if args.contains("--power-stop") { powerApply(.stop) }
```

**Steps:**
- [ ] Implement both classes + wiring + debug args; `swift build` green.
- [ ] Manual check: `swift run Tiler --power-start 10m` from a second shell:
      `pmset -g assertions | grep "Tiler Keep Awake"` shows the idle assertion;
      kill the process; grep again → gone.
- [ ] `swift test` green (no regressions). Commit:
      `feat(system): assertion + power-source adapters, debug args`.

### Task 1.4: Floor notification

**Files:**
- Create: `Sources/TilerSystem/PowerNotifier.swift`
- Modify: `Sources/Tiler/AppDelegate.swift` (`.notifyFloorStop` effect)

```swift
import UserNotifications
@MainActor public final class PowerNotifier {
    public init()
    public func requestAuthOnce()        // .alert+.sound; guard via UserDefaults flag
    public func floorStop(percent: Int)  // "Keep Awake stopped — battery at N%"
}
```

Call `requestAuthOnce()` on the first `.acquire` effect (lazy permission,
design.md). `.notifyFloorStop` → `floorStop(percent:)`.

**Steps:**
- [ ] Implement; `swift build && swift test` green.
- [ ] Commit: `feat: battery-floor notification`.

### Task 1.5: `AdminShell` + `DisableSleepGovernor` (the clamshell root path)

**Files:**
- Create: `Sources/TilerSystem/AdminShell.swift`,
  `Sources/TilerSystem/DisableSleepGovernor.swift`
- Test: `Tests/TilerCoreTests/…` is core-only — put these tests in
  `Tests/TilerIntegrationTests/AdminCommandTests.swift` (they are pure string
  tests; TilerIntegrationTests already imports TilerSystem)

**Produces:**

```swift
public enum AdminShellError: Error, Equatable {
    case cancelled
    case failed(status: Int32, message: String)
}
public enum AdminShell {
    public static func appleScriptLiteral(_ shell: String) -> String
    @discardableResult
    public static func runPrivileged(_ shell: String) throws -> String
}
@MainActor public final class DisableSleepGovernor {
    public static let sentinelPath = "/tmp/pro.amilabs.tilerx.clamshell.sentinel"
    public init(adminRun: @escaping @Sendable (String) throws -> String)
    public func arm(deadline: Date?) throws
    public func disarm()
    public func reconcileAtLaunch() -> Bool       // true = stale flag detected
    public static func sleepDisabledNow() -> Bool
    public static func armCommand(deadline: Date?, now: Date) -> String
}
```

`appleScriptLiteral`: escape `\` then `"`, wrap in quotes (TDD: plain, quoted,
backslash, newline cases). `runPrivileged` runs
`/usr/bin/osascript -e "do shell script \(literal) with administrator privileges"`
via `Process` + pipes; non-zero exit with stderr containing `User canceled` (also
match `-128`) → `.cancelled`, else `.failed`. `sleepDisabledNow()`: run
`/usr/bin/pmset -g`, regex `SleepDisabled\s+1` (absent key = false — macOS omits
it until first touched).

`armCommand(deadline:now:)` — pure composition, exact output locked by tests
(`D=0` for indefinite, else epoch of `deadline + 120` grace):

```sh
pmset -a disablesleep 1
nohup /bin/zsh -c 'S=/tmp/pro.amilabs.tilerx.clamshell.sentinel; D=<epoch|0>
while :; do
  [ -f "$S" ] || break
  A=$(( $(date +%s) - $(stat -f %m "$S") )); [ "$A" -lt 45 ] || break
  [ "$D" -eq 0 ] || [ "$(date +%s)" -lt "$D" ] || break
  sleep 15
done
pmset -a disablesleep 0
rm -f "$S"' >/dev/null 2>&1 &
```

`arm`: write the sentinel file first, start a 10 s `DispatchSourceTimer` that
refreshes its `.modificationDate`, then `try adminRun(Self.armCommand(…))`; on
throw: stop timer, remove sentinel, rethrow (AppDelegate converts a `.cancelled`
into `powerApply(.clamshellArmFailed)`). `disarm`: stop timer, remove sentinel
(watchdog restores the flag ≤15 s later, promptlessly — spec scenario).
`reconcileAtLaunch`: `sleepDisabledNow() && !FileManager.default.fileExists(atPath:
sentinelPath)` → show `NSAlert` ("Sleep is still disabled from a previous
session…", button "Restore normal sleep") → `adminRun("pmset -a disablesleep 0")`
(cancel = keep, log). Wire `.armClamshell`/`.disarmClamshell` effects and call
`reconcileAtLaunch()` from `setUpPower()`.

**Steps:**
- [ ] Tests first: `appleScriptLiteral` escaping cases; `armCommand` exact-string
      for `deadline: nil` and a fixed date (assert the epoch arithmetic and the
      45 s / 15 s constants appear). Run → FAIL.
- [ ] Implement; `swift test` green.
- [ ] Manual (no admin needed): temporarily `NSLog` `armCommand` output, paste the
      *watchdog body only* (without the pmset lines) into a shell with a test
      sentinel — confirm it exits when the file is deleted or goes stale.
- [ ] Commit: `feat(system): AdminShell + DisableSleepGovernor (sentinel watchdog)`.

### Task 2.1: [USER GATE] Rendered mockups before any UI wiring

Owner rule (2026-07-06): show pictures first, never build UI blind.

**Files:**
- Modify: `Sources/Tiler/AppDelegate.swift` (`renderShots`) — add renders of:
  (a) a `PowerMenuMockView` (SwiftUI picture of the future menu: header state
  line, 8 start items, lid-closed ⚠ toggle, Stop; two variants of the status-item
  indicator: `☕` text vs `cup.and.saucer.fill` glyph swap), (b) the Settings
  Power tab (task 2.3's view rendered standalone with stub model).
- Create: `Sources/Tiler/PowerMenuMockView.swift` (throwaway-quality is fine;
  it ships nothing).

**Steps:**
- [ ] Build mock views; `swift run Tiler --render-shots /tmp/power-mock` produces
      `power-menu.png`, `power-settings.png`; attach both to chat.
- [ ] STOP. Batched ask (Russian): approve naming/layout/indicator variant.
      Record the owner's picks in `design.md` (one line) and check off 2.1 in
      `tasks.md`. Commit: `docs: power UI mockups + owner picks`.

### Task 2.2: Menu Power section + status indicator

**Files:**
- Modify: `Sources/Tiler/AppDelegate.swift` — `setUpStatusItem()` (insert between
  the Settings item and the Quit separator), `menuWillOpen(_:)` (refresh), and
  `updateStatusGlyph()` (indicator per gate-2.1 pick).

Menu structure (`makeItem` helper already exists; keep target/self pattern):

```swift
// "Keep Awake" NSMenu submenu:
//   headerItem (disabled)      "Off" | "On — 27 min left" | "On (until stopped)" | "On — lid-closed ⚠"
//   separator
//   "On (until stopped)"       powerStart(nil)
//   "For 10 minutes" … "For 24 hours"   7 items, tag = minutes (10,30,60,120,300,600,1440)
//   separator
//   "Keep awake with lid closed ⚠"     transient checkbox (state = pendingClamshell)
//   separator
//   "Stop"                     enabled only while active
```

`pendingClamshell` is a `var` on AppDelegate reset to `false` after every start
(spec: opt-in friction each session). Start actions call
`powerApply(.start(clamshell: pendingClamshell, duration: minutes.map { $0 * 60 }))`
— for clamshell the `.armClamshell` effect triggers the governor, whose
`.cancelled` maps to `powerApply(.clamshellArmFailed)`. Header + Stop + checkbox
states refresh in `menuWillOpen` from `powerPolicy` (`remaining(now:)` → "N min
left", hours ≥ 2 shown as "H h M min"). Status indicator appears while active
(coexists with ⚠, task-2.1 pick).

**Steps:**
- [ ] Implement; `swift build`; run, exercise all menu paths manually
      (non-clamshell); `pmset -g assertions` greps confirm acquire/release.
- [ ] `swift test` green. Commit: `feat(ui): Keep Awake menu + status indicator`.

### Task 2.3: Settings Power tab + Guide section

**Files:**
- Modify: `Sources/Tiler/SettingsWindow.swift` — extend `SettingsModel`
  (`keepDisplayAwake`, `batteryFloorPercent`, `deepSleepOnBattery` @Published,
  `didSet` → store, plus `onDeepSleepToggle: ((Bool) -> Void)?` and
  `func reflectDeepSleep(_ actual: Bool)` for revert-on-cancel), add third tab:

```swift
powerTab.tabItem { Label("Power", systemImage: "bolt") }

private var powerTab: some View {
    Form {
        Section("Keep Awake") {
            Toggle("Keep display awake too", isOn: $model.keepDisplayAwake)
            Picker("Stop when battery below", selection: $model.batteryFloorPercent) {
                Text("Off").tag(0)
                Text("30%").tag(30); Text("20%").tag(20); Text("10%").tag(10)
            }
        }
        Section("Deep Sleep") {
            Toggle("Deep Sleep on lid close (battery)", isOn: $model.deepSleepOnBattery)
            Text("Sleep on battery writes memory to disk and powers it off — "
                 + "near-zero drain, wake takes 10–20 s. Changing this asks for "
                 + "an administrator password.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    .formStyle(.grouped)
}
```

  (window frame 460×320 must still fit — no-scroll rule; verify visually.)
- Modify: `Sources/Tiler/GuideWindow.swift` — add a "Power" block to the guide
  following its existing section pattern: sessions + durations; floor; lid-closed
  ⚠ "admin password, heat — never in a bag"; Deep Sleep wake-time caveat;
  precedence line "active session ≻ Deep Sleep profile ≻ system defaults".

**Steps:**
- [ ] Implement; `--show-settings` / `--show-guide` smoke-run; re-render README
      shots later at release (4.3), not now.
- [ ] `swift test` green. Commit: `feat(ui): Settings Power tab + Guide section`.

### Task 3.1: `PmsetCustomParser` (core) + `PowerProfileController`

**Files:**
- Create: `Sources/TilerCore/PmsetCustomParser.swift`,
  `Sources/TilerSystem/PowerProfileController.swift`
- Test: `Tests/TilerCoreTests/PmsetCustomParserTests.swift` (+ fixture
  `Tests/TilerCoreTests/Fixtures/pmset-custom.txt` — capture real output:
  `pmset -g custom > Tests/TilerCoreTests/Fixtures/pmset-custom.txt`)
- Test: `Tests/TilerIntegrationTests/PowerProfileCommandTests.swift` (pure
  command-composition tests)

**Produces:**

```swift
public enum PmsetCustomParser {
    public static func batterySettings(from output: String) -> [String: String]
}   // parses the "Battery Power:" section: lines "key<space>value" until next header

@MainActor public final class PowerProfileController {
    public init(store: SettingsStore, adminRun: @escaping @Sendable (String) throws -> String)
    public func isDeepSleepActive() -> Bool     // batterySettings()["hibernatemode"] == "25"
    public func enable() throws                 // snapshot current → store.powerSnapshot → apply
    public func disable() throws                // restore snapshot verbatim; nil snapshot → defaults
    public static func applyCommand(current: [String: String]) -> String
    public static func restoreCommand(snapshot: [String: String]) -> String
}
```

`applyCommand`: single invocation `pmset -b hibernatemode 25 powernap 0
tcpkeepalive 0` + ` proximitywake 0` appended only when the key exists in
`current`. `restoreCommand`: `pmset -b` + each snapshotted key we touched
(hibernatemode, powernap, tcpkeepalive, proximitywake-if-present) with its old
value; empty/missing snapshot → Apple portable defaults `hibernatemode 3
powernap 1 tcpkeepalive 1` (spec). Snapshot only these keys, not the whole map.
Launch reconciliation (wire into `setUpPower()`): `settings.deepSleepOnBattery =
profile.isDeepSleepActive()` — reality wins over stored intent (spec scenario
"Manual pmset edits"); `SettingsModel.reflectDeepSleep` keeps an open Settings
window honest. AppDelegate hook (from task 2.3's `onDeepSleepToggle`): call
`enable()`/`disable()`; on `AdminShellError.cancelled` or `.failed` → NSLog,
re-read `isDeepSleepActive()`, `reflectDeepSleep(actual)` (spec scenario
"Authorization cancelled").

**Steps:**
- [ ] Capture the fixture; parser tests (header split, key/value, missing section
      → `[:]`); run FAIL → implement → green.
- [ ] Command tests: exact strings for apply (with/without proximitywake) and
      restore (snapshot present / nil). FAIL → implement → green.
- [ ] Wire AppDelegate + reconciliation; `swift build && swift test` green.
- [ ] Commit: `feat: Deep Sleep profile controller (pmset battery-side)`.

### Task 3.2 (folded into 3.1 wiring): failure paths

Covered above: auth-cancel revert, post-write re-read, defaults-restore. Verify
each once by hand (cancel the dialog when toggling) and check off in `tasks.md`.

### Task 4.1: Acceptance script

**Files:**
- Create: `Scripts/power-acceptance.sh` (chmod +x; do NOT touch
  `run-acceptance.sh` — it is AX-gated, power checks need no AX)

```sh
#!/bin/zsh
# Power acceptance: assertion lifecycle incl. crash safety. No AX, no admin needed.
set -u
BIN=.build/debug/Tiler
FAIL=0
note() { print -- "== $1" }
swift build >/dev/null || exit 1

note "start 10m session"
$BIN --power-start 10m & PID=$!
sleep 2
pmset -g assertions | grep -q "Tiler Keep Awake (idle)" || { print "FAIL: assertion missing"; FAIL=1 }

note "clean stop releases"
kill -TERM $PID; sleep 2
pmset -g assertions | grep -q "Tiler Keep Awake" && { print "FAIL: assertion survived TERM"; FAIL=1 }

note "kill -9 crash safety"
$BIN --power-start 10m & PID=$!
sleep 2
kill -9 $PID; sleep 2
pmset -g assertions | grep -q "Tiler Keep Awake" && { print "FAIL: assertion survived SIGKILL"; FAIL=1 }

[ $FAIL -eq 0 ] && print "POWER ACCEPTANCE: ALL PASS"
exit $FAIL
```

**Steps:**
- [ ] Create + run: `Scripts/power-acceptance.sh` → `ALL PASS`.
- [ ] Full `swift build && swift test` + `Scripts/run-acceptance.sh` (regressions;
      needs AX on the host — if unavailable, note it and leave for gate 4.2).
- [ ] Commit: `test: power acceptance (assertions incl. SIGKILL)`.

### Task 4.2: [USER GATE] Hands-on acceptance (batched, Russian, ~15 min)

Prepare everything, then one batched ask. The owner verifies on real hardware:
1. Timed session (10 min → expiry) + menu countdown; floor stop (set floor 30%
   when battery is just below — or wait for a natural crossing).
2. Lid-closed session: admin dialog (`ami`), lid closed 2–3 min → awake
   (reuse `spike/clamshell_spike.swift battery` methodology: it now measures ANY
   holder, Tiler included); after Stop → `pmset -g` shows `SleepDisabled 0`
   within ~15 s, no second dialog. Force-quit variant: flag clears ≤60 s.
3. Deep Sleep: toggle on (dialog), `pmset -g custom` shows battery 25/0/0;
   lid close on battery → wake takes ~10–20 s; toggle off → snapshot restored
   verbatim (diff `pmset -g custom` before/after).
4. Overnight drain note (optional but valuable): Deep Sleep on, note %.
Record outcomes in `tasks.md`; any failure = fix before proceeding.

### Task 4.3: Merge specs, archive, release v0.3.0

**Steps:**
- [ ] Merge this change's spec deltas into `openspec/specs/` (new
      `openspec/specs/power/spec.md`; fold the app-shell and settings deltas into
      their merged specs), update `openspec/project.md` (move the change to the
      archived list) and `CLAUDE.md` step 2 (no active change).
- [ ] `git mv openspec/changes/add-power-control
      openspec/changes/archive/2026-07-XX-add-power-control` (use the real date).
- [ ] Bump `AppDelegate.version` to `"0.3.0"`; re-render README shots
      (`--render-shots`) since Settings gained a tab; update README feature list.
- [ ] `swift build && swift test` + both acceptance scripts green.
- [ ] `Scripts/make-app.sh && Scripts/install.sh`; owner confirms launch.
- [ ] Tag + release: `git tag v0.3.0 && git push origin main v0.3.0`, then
      `ditto -c -k --keepParent build/Tiler.app /tmp/Tiler-0.3.0.zip &&
      gh release create v0.3.0 /tmp/Tiler-0.3.0.zip --title "Tiler 0.3.0" -n
      "Keep Awake sessions, battery floor, lid-closed mode, Deep Sleep profile."`

---

## Self-review notes (already applied)

- Spec coverage: every requirement/scenario in `specs/power/spec.md`,
  `specs/app-shell/spec.md`, `specs/settings/spec.md` maps to tasks 1.1–4.2;
  the two clamshell hands-on scenarios land in gate 4.2 by design.
- Type names are consistent across tasks (`AssertionSpec`, `PowerCommand`,
  `PowerEffect`, `PowerStatus`, governor/controller signatures).
- No placeholders; all commands/strings are exact. The only deliberately
  deferred items are the two [USER GATE] stops (2.1 mockup picks, 4.2 hands-on).

## Escalation

If something resists for more than ~3 attempts (Swift 6 concurrency fights,
IOKit surprises, powerd behaving differently than the spike logs), stop and tell
the owner (Russian) — he will bring in Fable (the session that authored this
brief and ran the spike). Evidence to attach: exact error, `pmset -g assertions`
/ `pmset -g` output, the failing command.
