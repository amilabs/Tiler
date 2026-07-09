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
- [x] 2.3 Settings Power tab + Guide/Help Power section (heat warning, wake-time
      caveat, precedence note).
      → DONE 2026-07-08: SettingsModel gained keepDisplayAwake/batteryFloorPercent/
      deepSleepOnBattery (+ onDeepSleepToggle/reflectDeepSleep for revert-on-cancel);
      third "Power" tab (Prevent Sleep + Deep Sleep sections). Guide gained a
      "Prevent Sleep & Deep Sleep" block (durations, floor, lid-closed heat ⚠,
      wake caveat, precedence). --show-settings/--show-guide construct; guide
      render verified. Non-AX tests green.

## 3. Deep Sleep profile
- [x] 3.1 `PowerProfileController`: `pmset -g custom` snapshot/parse (parser in
      TilerCore, TDD with a captured fixture); battery-side apply
      (`hibernatemode 25`, `powernap 0`, `tcpkeepalive 0`, `proximitywake 0`
      where present) and verbatim restore via `AdminShell` (from 1.5);
      launch reconciliation with actual pmset state.
      → DONE 2026-07-08: `PmsetCustomParser` (5 tests, real fixture; multi-word
      keys, section boundary) + `PowerProfileController` (5 command tests; apply
      w/ and w/o proximitywake, restore verbatim/defaults). AppDelegate wires
      enable/disable via `onDeepSleepToggle` and launch reconciliation
      (`settings.deepSleepOnBattery = profile.isDeepSleepActive()`). Launch smoke
      OK, pmset profile untouched (no live enable — deferred to gate 4.2).
- [x] 3.2 Failure paths: auth cancel reverts toggle; post-write re-read; missing
      snapshot → Apple portable defaults.
      → Wired in 3.1: `applyDeepSleep` catches AdminShellError, re-reads
      `isDeepSleepActive()`, calls `reflectDeepSleep(actual)`; empty snapshot →
      portable defaults (unit-tested). Hands-on cancel verification at gate 4.2.

## 4. Verification & release
- [x] 4.1 Full `swift build && swift test` + acceptance additions: assertion
      present/absent/kill -9 crash-safety greps.
      → DONE 2026-07-08: `Scripts/power-acceptance.sh` → POWER ACCEPTANCE: ALL
      PASS (idle assertion present; released on SIGTERM and SIGKILL). Full
      `swift test` = 155/155 across 23 suites (incl. AX window E2E). Bundled
      `Scripts/run-acceptance.sh` (needs the signed .app) runs at 4.3 release;
      my changes don't touch its launch-health/idle-CPU/crash paths.
- [ ] 4.2 [USER GATE — hands-on acceptance] timed expiry, floor stop, lid-closed
      awake session, Deep Sleep hibernate + wake (~10–20 s) + verbatim restore;
      overnight drain sanity note.
      → 2026-07-08 PREPARED, AWAITING OWNER HANDS-ON: signed .app built
      (`make-app.sh`) + installed to ~/Applications/Tiler.app (`install.sh`),
      launched; installed release binary verified holding/releasing the idle
      assertion incl. kill -9. Checklist posted (timed+countdown, floor, clamshell
      `ami` dialog + `pmset -g` SleepDisabled 0 within ~15 s + force-quit ≤60 s,
      Deep Sleep 25/0/0 + verbatim restore). Version still 0.2.6 (bump at 4.3).
      Do not proceed to 4.3 until the owner confirms; any failure = fix first.
- [ ] 4.3 Merge spec deltas into `openspec/specs/`, archive change, bump
      `AppDelegate.version`, release v0.3.0 (`gh release`).

## 5. Gate-4.2 refinements (owner feedback, 2026-07-08)
- [x] 5.1 Prominent active-state row at the top of the main menu (bold, red-cup mark,
      state + remaining time) shown only while a session runs; live 1 s countdown for
      timed sessions while the menu is open (`menuWillOpen`/`menuDidClose`).
      Spec: app-shell "Menu Power section" updated. Mock re-rendered + owner-confirmed.
- [x] 5.2 Opt-in "Debug logging" (Settings → Power → Diagnostics) → event-driven,
      deduped, size-capped (~512 KB rotate, ≤~1 MB) log at
      `~/Library/Logs/Tiler/power-debug.log`; "Reveal Log" button. `PowerDebugLog`
      + `plog` at every power event; SettingsStore `powerDebugLogging` (+ test).
      Verified end-to-end (launch/start/acquire lines written). Spec: power
      "Diagnostic logging" + settings Power tab updated.
      → Extended acceptance plan (supersedes one-shot hands-on): owner enables
      logging, runs timed/floor/clamshell/Deep-Sleep over days, then the log is
      reviewed for anomalies. Gate 4.2 stays open until that review.
- [x] 5.3 Top row click stops the session; submenu marks the running start choice
      (✓ on until-stopped / the chosen duration). Spec app-shell updated.
- [x] 5.4 Richer diagnostics (owner: "не скромничай"): ~15 s liveness heartbeat while
      active (elapsed/power/lid/held — a gap = real sleep), system + screen sleep/wake
      with lid state (`SystemPower.lidClosed()` via IORegistry `AppleClamshellState`),
      held summary on acquire, richer launch line; size cap raised to ~5 MB × 3 backups
      (~20 MB). Verified: launch/heartbeat lines carry lid state. Spec power updated.
- [x] 5.5 About/Guide window: content wrapped in a scroll view capped at 640 h (fits
      laptops) with an always-visible scrollbar — render-shots still draws it
      full-height for the README; reference sections carded for visual separation.
- [x] 5.6 Round-3 owner feedback: (a) Settings window was too short for the Power tab's
      three sections (Form scrolled internally, non-obvious) → height 320→450 so it
      fits without scroll; (b) top-row click now shows a Stop/Cancel confirm (submenu
      Stop stays direct); (c) log now captures screen lock/unlock (distributed
      notifications, incl. ⌃A) with lid state. Specs app-shell/power updated.
- [x] 5.7 Round-4: 450 still scrolled (the `.frame(height:)` includes the ~40px tab
      bar, leaving the Form ~410 vs ~437 needed) → 520. About's overlay scrollbar was
      invisible until scrolled (`.scrollIndicators(.visible)` doesn't force it on
      macOS) → `AuxWindow` now flashes the scrollers on open so the scroll advertises
      itself. Top-row confirm verified by owner.
- [x] 5.8 Gesture recovery after wake (found via the gate-4.2 diagnostic log): the
      log showed a real 2 h hibernate (Deep Sleep test) with a 7050 s heartbeat gap,
      wake at lid-open, then the owner's manual relaunch — the MultitouchSupport
      stream had died across sleep. Fix: rebuild the touch stream 1.5 s after
      `didWakeNotification` (stop()+start() → fresh device list); fallback to full
      pipeline rebuild. Spec app-shell "Gesture recovery after system wake" added.
      DIAGNOSIS: no power-feature anomalies in the ~16 h log — Deep Sleep hibernated
      and woke cleanly, disable restored without error, no stale sleepDisabled at any
      launch, screen-lock with an active session kept the system awake (display only
      slept), battery never neared the floor. Clamshell/floor paths not exercised yet.
