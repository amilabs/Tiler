# Tasks — add-power-control

## 0. Approvals & feasibility (blocking)
- [ ] 0.1 [USER GATE] Proposal + design approved; privilege model chosen
      (A: admin prompt per Deep Sleep toggle — recommended; B: one-time root
      helper daemon); clamshell `disablesleep` fallback pre-approved / rejected.
- [ ] 0.2 [USER GATE — ~5 min hands-on] Clamshell spike on the owner's machine:
      scripted assertion holder (debug flag `--spike-clamshell`), owner closes the
      lid twice (battery / AC), script logs sleep-vs-awake via wall-clock gap +
      `pmset -g log`. Results protocoled in design.md.
- [ ] 0.3 Fix the lid-closed approach per spike + gate (assertion / fallback /
      AC-only / dropped) and update spec delta accordingly.

## 1. Core (TDD, no root)
- [ ] 1.1 `PowerPolicy` FSM in TilerCore (TDD): indefinite/timed sessions, expiry,
      replacement, battery floor on-battery-only, stop reasons, no auto-restart.
- [ ] 1.2 SettingsStore: `keepDisplayAwake` / `batteryFloorPercent` /
      `deepSleepOnBattery` / `powerSnapshot` + integration tests.
- [ ] 1.3 `AwakeController` (assertion lifecycle incl. display hold + clamshell spec)
      + `PowerSourceMonitor` (IOPS events); AppDelegate wiring; NSLog state lines.
- [ ] 1.4 UserNotifications: floor auto-stop banner (lazy permission request).

## 2. UI (mockups first — owner rule)
- [ ] 2.1 [USER GATE] Rendered mockups via `--render-shots`: menu Power section,
      Settings Power tab, status-glyph active state → owner sign-off on
      naming/layout/glyph before wiring.
- [ ] 2.2 Menu: Keep Awake submenu (durations, lid-closed ⚠ option resetting per
      session, Stop, remaining-time header) refreshed in `menuWillOpen`; status item
      session state.
- [ ] 2.3 Settings Power tab + Guide/Help Power section (heat warning, wake-time
      caveat, precedence note).

## 3. Deep Sleep profile
- [ ] 3.1 `PowerProfileController`: `pmset -g custom` snapshot/parse; battery-side
      apply (`hibernatemode 25`, `powernap 0`, `tcpkeepalive 0`, `proximitywake 0`
      where present) and verbatim restore via `AdminShell` (path per gate 0.1);
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
