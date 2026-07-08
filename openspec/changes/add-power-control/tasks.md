# Tasks — add-power-control

## 0. Approvals & feasibility (blocking)
- [x] 0.1 [USER GATE] Proposal + design approved; privilege model chosen.
      → APPROVED 2026-07-08: design OK, model A (admin prompt per toggle);
      `disablesleep` fallback decision moved to gate 0.3 (after spike evidence).
- [ ] 0.2 [USER GATE — ~8 min hands-on] Clamshell spike on the owner's machine:
      `spike/clamshell_spike.swift` (standalone script — supersedes the planned
      app debug flag; selftest PASS 2026-07-08, privilege probes already
      protocoled in design.md). Three phases: `battery` / `ac` / `fallback`
      (battery + `sudo pmset -a disablesleep 1`); owner closes the lid ~2 min
      per phase; verdicts in `spike/spike-*.log`. Results → design.md.
      → DONE 2026-07-08: battery = SLEPT (118.2 s gap / 124 s closed; CoffeeTea
      assertions also present — a fortiori), fallback = STAYED AWAKE (399 s,
      max gap 2.0 s), ac = STAYED AWAKE (253 s, max gap 2.0 s; effective-row
      cross-check PreventSystemSleep 0-on-battery/1-on-AC). Flag restored
      (SleepDisabled 0 verified). Full table + caveats in design.md.
- [x] 0.3 Lid-closed approach fixed per spike (2026-07-08): `disablesleep` +
      single-prompt root watchdog (sentinel file) uniformly; public assertions
      held alongside; auth cancel = no session; launch reconciliation. Power
      spec delta updated.
- [x] 0.4 Detailed implementation brief for the implementing session —
      `implementation-brief.md` (2026-07-08): global constraints, exact
      interfaces per task (mirrors phases 1–4 below), TDD cycles with code,
      acceptance script, gate protocol, escalation note. Owner: implementation
      runs in a fresh session on Opus; escalate to Fable if it gets stuck.

## 1. Core (TDD, no root)
- [x] 1.1 `PowerPolicy` FSM in TilerCore (TDD): indefinite/timed sessions, expiry,
      replacement, battery floor on-battery-only, stop reasons, no auto-restart.
      → DONE 2026-07-08: `Sources/TilerCore/PowerPolicy.swift` + 25 tests
      (`PowerPolicyTests`), all green; every semantics bullet covered.
- [x] 1.2 SettingsStore: `keepDisplayAwake` / `batteryFloorPercent` /
      `deepSleepOnBattery` / `powerSnapshot` + integration tests.
      → DONE 2026-07-08: 4 keys added (didSet/onChange; powerSnapshot is
      bookkeeping-only, no onChange), 5 round-trip/notify tests green.
- [x] 1.3 `AwakeController` (assertion lifecycle incl. display hold + clamshell spec)
      + `PowerSourceMonitor` (IOPS events); AppDelegate wiring; NSLog state lines.
      → DONE 2026-07-08: manual check — `--power-start 10m` shows
      `PreventUserIdleSystemSleep named: "Tiler Keep Awake (idle)"`; released on
      both SIGTERM and SIGKILL (crash safety). `--power-start`/`--power-stop`
      debug args + 5 s tick timer + settings feed wired. 126 non-AX tests green.
- [x] 1.4 UserNotifications: floor auto-stop banner (lazy permission request).
      → DONE 2026-07-08: `PowerNotifier` (requestAuthOnce on first .acquire,
      floorStop banner); guarded on `Bundle.main.bundleIdentifier` so the
      unbundled acceptance binary never aborts on `UNUserNotificationCenter`.
- [x] 1.5 `AdminShell` (osascript admin-auth wrapper, AppleScript escaping
      TDD-able) + `DisableSleepGovernor` (sentinel lifecycle, watchdog arming
      command, launch reconciliation; shell-command composition TDD-able).
      → DONE 2026-07-08: 7 pure tests (appleScriptLiteral escaping incl. raw
      newline; armCommand exact bytes for indefinite/timed + 45/15 constants).
      Watchdog LOOP verified in scratchpad (fast constants): restores on
      sentinel delete / stale (in-a-bag crash) / deadline-passed; stays awake
      while fresh. AppDelegate wires arm/disarm + launch reconciliation;
      arm-failure → `.clamshellArmFailed` teardown. SleepDisabled untouched (0).

## 2. UI (mockups first — owner rule)
- [x] 2.1 [USER GATE] Rendered mockups via `--render-shots`: menu Power section,
      Settings Power tab, status-glyph active state → owner sign-off on
      naming/layout/glyph before wiring.
      → SIGNED OFF 2026-07-08 (5 mockup rounds). Owner picks:
      (1) label the feature **"Prevent Sleep"** in all UI (internal assertion
      names keep "Tiler Keep Awake …" for greps);
      (2) status indicator = monochrome `hand.pinch.fill` + a solid **red disc
      with a white `cup.and.saucer.fill` silhouette** at the bottom-right (static,
      no live countdown), coexists with ⚠;
      (3) menu wording + Power-tab layout approved as mocked.
      Recorded in design.md. `PowerMenuMockView` is throwaway render tooling.
- [x] 2.2 Menu: Keep Awake submenu (durations, lid-closed ⚠ option resetting per
      session, Stop, remaining-time header) refreshed in `menuWillOpen`; status item
      session state.
      → DONE 2026-07-08: "Prevent Sleep" submenu (header/indefinite/7 durations/
      clamshell checkbox/Stop), `pendingClamshell` resets per start; status
      indicator = red disc + white cup badge on the hand while active (gate 2.1
      pick), re-rendered only on active/appearance change. Notifier banner +
      tooltip renamed. Launch+active-session smoke: menu builds, indicator
      renders, assertion held. Non-AX tests green.
- [ ] 2.3 Settings Power tab + Guide/Help Power section (heat warning, wake-time
      caveat, precedence note).

## 3. Deep Sleep profile
- [ ] 3.1 `PowerProfileController`: `pmset -g custom` snapshot/parse (parser in
      TilerCore, TDD with a captured fixture); battery-side apply
      (`hibernatemode 25`, `powernap 0`, `tcpkeepalive 0`, `proximitywake 0`
      where present) and verbatim restore via `AdminShell` (from 1.5);
      launch reconciliation with actual pmset state.
- [ ] 3.2 Failure paths: auth cancel reverts toggle; post-write re-read; missing
      snapshot → Apple portable defaults.

## 4. Verification & release
- [ ] 4.1 Full `swift build && swift test` + acceptance additions: assertion
      present/absent/kill -9 crash-safety greps.
- [ ] 4.2 [USER GATE — hands-on acceptance] timed expiry, floor stop, lid-closed
      awake session, Deep Sleep hibernate + wake (~10–20 s) + verbatim restore;
      overnight drain sanity note.
- [ ] 4.3 Merge spec deltas into `openspec/specs/`, archive change, bump
      `AppDelegate.version`, release v0.3.0 (`gh release`).
