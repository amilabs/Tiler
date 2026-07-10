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
- [x] 4.2 [USER GATE — hands-on acceptance] timed expiry, floor stop, lid-closed
      awake session, Deep Sleep hibernate + wake (~10–20 s) + verbatim restore;
      overnight drain sanity note.
      → 2026-07-08 PREPARED, then PASSED over 2026-07-08..10 across many owner
      hands-on runs (each logged with debug logging on, reviewed for anomalies):
      timed countdown + expiry release, Deep Sleep hibernate (~2 h, verbatim
      restore, clean wake), clamshell HOLD (~44 min, 179 continuous lid=closed
      heartbeats — task 5.13), clamshell expiry-with-lid-closed → promptless
      restore + auto-sleep (5.18/6.4), promptless restore across stop/expiry/
      force-quit (5.17), screen-lock with an active session keeping the system
      awake. No power-feature anomalies in the ~16 h + subsequent logs (6.x
      diagnosis). Owner sign-off = "надо релиз выложить" (release it for testing
      on other laptops).
- [x] 4.3 Merge spec deltas into `openspec/specs/`, archive change, bump
      `AppDelegate.version`, release v0.3.0 (`gh release`).
      → DONE 2026-07-10: power delta → new `openspec/specs/power/spec.md`; app-shell
      delta (Menu Power section / Status item session state / Gesture recovery after
      system wake) + settings delta (Power tab incl. Diagnostics) folded into their
      merged specs; diagnostic-logging bound corrected to the shipped 100 MB×1
      (~200 MB). Version 0.2.6→0.3.0 (AppDelegate + make-app.sh). Throwaway mock
      views removed (`PowerMenuMockView` + render-shots power lines). `power-
      acceptance.sh` made PID-keyed (safe alongside a live session). README gained a
      Prevent Sleep section + bullet; `docs/screenshots/guide.png` re-rendered.
      Verified: `swift build` + 147 non-AX tests + power-acceptance + run-acceptance
      (signed .app: launch health, idle CPU, kill-9 resilience) all green (AX window
      E2E last run 155/155 at 4.1; skipped here to avoid moving the owner's live
      windows). project.md/CLAUDE.md pointers updated;
      change folder archived → `archive/2026-07-10-add-power-control`. Tagged v0.3.0
      + `gh release` with zip.

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
- [x] 5.9 Clamshell never started (owner: "не сработало с закрытой крышкой"). Log
      root cause: EVERY start was `clamshell=false` — the "with lid closed" checkbox
      closed the menu, so it could not be set together with a duration; the
      disablesleep+watchdog path was never invoked (Mac correctly slept on a
      non-clamshell session). Fix: replaced the checkbox with a nested "With lid
      closed ⚠" submenu of the same start choices → atomic, discoverable clamshell
      start (heat warning as a disabled header). Specs app-shell/power updated; mock
      re-rendered. Clamshell mechanism itself still needs a real hands-on run.
      → SUPERSEDED by 5.10: owner rejected the nested submenu as interface
      duplication.
- [x] 5.10 Clamshell UX (final): single "Prevent sleep with lid closed…" ⚠ item opens
      a dialog (duration popup + heat warning + Start/Cancel) → one atomic step, no
      duplicated duration list, no menu-closing checkbox. Specs app-shell/power +
      mock updated. Still needs a real hands-on clamshell run to exercise the
      disablesleep+watchdog mechanism.
- [x] 5.11 Dialog polish (owner): (a) reuse the menu timer — the dialog pre-selects
      the running duration (else 2 h) and the menu's duration list marks the running
      timer for BOTH normal and lid-closed sessions; (b) a heat-warning image in the
      dialog — a laptop going into a backpack, crossed out by the red prohibitory sign
      (backpack.fill + laptopcomputer + nosign, rendered to the alert icon). Mock +
      specs updated.
- [x] 5.12 [MINI-GATE, owner sign-off before wiring] Owner reminded me to approve UI
      on mockups first. Rendered 5 warning-image variants (light/dark) + a help-styled
      dialog mock (`ClamshellMockView`). Owner picked image **5 (bag + laptop +
      nosign)** and approved the **help-styled centered dialog**. Implemented:
      `ClamshellDialog.swift` (SwiftUI `ClamshellDialogView` + model), shown as a
      non-modal floating card window from `promptClamshellStart` (replaces the plain
      NSAlert), reusing the menu timer (pre-select). Spec app-shell updated.
- [x] 5.13 Clamshell HOLD verified on real hardware (gate-4.2 log): a lid-closed
      session on battery held the Mac awake ~44 min (179 continuous `lid=closed
      held=idle+system` heartbeats, no gap, no `system willSleep`). Touch-stream wake
      recovery also confirmed (`touch stream restarted after wake`).
- [ ] 5.14 [BUG — restore] `SleepDisabled 1` got stuck (no session). Two issues:
      (a) `reconcileAtLaunch` only fired when the sentinel was ABSENT, but a force-quit
      leaves a stale-but-present sentinel → the leftover flag was never offered for
      restore across relaunches. FIXED: reconcile on the flag at launch regardless of
      the sentinel (+ remove the sentinel on restore).
      (b) DEEPER: the detached root watchdog (`osascript … with administrator
      privileges &`) exited WITHOUT restoring (flag still 1, sentinel not removed) —
      the spike restored the flag manually, never via this detached watchdog, so the
      restore path is unproven and looks unreliable. Needs a clean controlled test
      (single clamshell → clean Stop → flag clears ≤15 s?; force-quit → ≤60 s?); if it
      fails, escalate to Fable (watchdog design / model-B root daemon).
      → CONFIRMED BROKEN 2026-07-09 (owner clean test): after Stop, SleepDisabled
      stayed 1. Diagnosis: a headless test (`scratchpad/detach-test.sh`) proves the
      detached `nohup zsh` watchdog launched via `osascript do shell script` (NO admin)
      survives osascript's return AND runs its cleanup on sentinel removal — so detach
      + loop logic are fine. The only delta in the real path is
      `with administrator privileges` + `pmset`: the flag SET works (arm's foreground
      `pmset -a disablesleep 1` runs as root), but the backgrounded watchdog's
      `pmset -a disablesleep 0` does not restore → the `&`-detached child almost
      certainly is NOT root (`do shell script … &` is a known-unreliable way to run a
      persistent privileged process; the documented-correct way is a launchd daemon =
      model B). ESCALATE to Fable (designed the watchdog + ran the spike, which restored
      the flag manually, never via this detached watchdog). Part-1 reconcile fix WORKS
      (owner cleared the stuck flag with it). Clamshell must not ship until restore is
      reliable.
      → ROOT CAUSE PROVEN 2026-07-09 (owner admin test, `scratchpad/detach-test.sh`
      logic via osascript): with `with administrator privileges`, the FOREGROUND runs
      as root (`fg_uid=0`) but the backgrounded `&` child never writes even its first
      line → the privileged wrapper reaps the whole process tree, so the detached
      watchdog is killed instantly. The flag SET works (foreground, root); the RESTORE
      never runs (watchdog dead). `do shell script … &` cannot host a persistent root
      process — the correct mechanism is a launchd daemon (model B, SMAppService).
      DECISION PENDING (owner): escalate to Fable vs. implement model B here.
- [x] 5.15 Restore rework (owner-approved: self-check + foreground dialog, NO model B).
      Removed the detached watchdog entirely (armCommand / sentinel / refresh timer /
      armCommand tests). `DisableSleepGovernor` now: `arm` = foreground
      `pmset -a disablesleep 1` (one admin prompt, runs as root — proven), `disarm` =
      foreground `pmset -a disablesleep 0` (prompts only if the ~5 min admin cache
      expired), `promptRestore` = alert + foreground restore. AppDelegate
      `reconcileStuckSleepDisabled()` (flag set & no live clamshell session → offer
      restore) runs at launch AND on wake; disarm on session end (Stop/expiry/floor).
      Spec power lid-closed requirement rewritten. 141 unit tests + power-acceptance
      green; flag stays 0. Needs the owner's hands-on clamshell re-test (start → Stop →
      SleepDisabled 0).
- [x] 5.16 "Until a specific time…" end date/time for Prevent Sleep (owner request).
      Mock → sign-off (label iterated: Custom… → Custom duration… → owner clarified he
      needs an END date/time, so "Until a specific time…"). Implemented:
      `UntilTimeDialogView` (DatePicker date+time, "from now" hint) for the normal menu
      item, and an "Until a specific time" option added to the lid-closed dialog's
      picker (reveals the DatePicker). `PowerDuration` shared tag/duration resolver
      (0=indefinite, -1=until-time, else minutes); dialogs auto-size
      (`sizingOptions=.preferredContentSize`) so the picker can grow the window. Active
      marker handles the -1 (custom) case. Specs app-shell updated. 141 tests +
      acceptance green.
- [x] 5.17 Clamshell restore — FINAL fix. Owner: the 2nd (restore) prompt ALWAYS
      appears, even after 10 s — the ~5 min `do shell script` admin cache does NOT carry
      across separate osascript invocations. Root insight proven headless
      (`scratchpad/detach-test.sh` + a foreground test): the reap only hit the
      BACKGROUNDED `&` child; a FOREGROUND osascript command runs as root, SURVIVES the
      app's death, and restores when the sentinel is removed. So the watchdog is back —
      as the foreground command of ONE async `osascript … with administrator
      privileges`: ONE prompt at start, PROMPTLESS restore on
      stop/expiry/floor/crash/quit/in-a-bag (sentinel removal, staleness, or deadline).
      `arm(deadline:onArmFailed:)` async + terminationHandler (no "started" marker =
      cancelled → teardown); `disarm` just removes the sentinel; `restoreNow` (foreground
      admin) is the rare launch/wake backstop. The leftover-flag alert now carries the
      backpack heat-warning graphic + danger text (owner request). armCommand back under
      test (asserts NO `nohup`/`&`). 144 tests + acceptance green. This ALSO closes the
      in-a-bag gap → model B not needed. Needs owner hands-on: start clamshell → Stop →
      SleepDisabled 0 with NO second password.
- [x] 5.18 Bug found reviewing the gate-4.2 log: the "started" cancel-detection marker
      was written by the ROOT watchdog into sticky `/tmp`, so the non-root app could
      never delete it → after the first clamshell session a stale root-owned marker
      would make the NEXT start's cancel detection always read "armed". Moved the marker
      to the per-user temp dir (`NSTemporaryDirectory()`, non-sticky, app-owned) so the
      app can create/remove it; the root watchdog can still write there. (The sentinel
      stays in /tmp — the app owns it.) armCommand test references the dynamic paths.
      NOTE: the gate-4.2 "expiry with lid closed" case was NOT actually exercised (the
      owner relaunched the app ~1.5 min into a 10-min clamshell); the relaunch did prove
      the crash-safe promptless restore (`sleepDisabled=false` at the next launch).
      → 2026-07-09 the owner then DID run the expiry (10-min clamshell, lid closed,
      deadline 17:25:34): Tiler correctly did `clamshell disarm` + `release expired` at
      the deadline, no dialog, flag→0. The Mac did NOT sleep afterward, but that is
      external to Tiler (coreaudiod holds `PreventUserIdleSystemSleep` ~7 h + the owner's
      "prevent sleep while working" setting) — Tiler had released everything.

## 6. Diagnostics deepening (owner, 2026-07-09)
- [x] 6.1 [RELEASE BLOCKER — false gesture positive] Owner saw a window move
      (left → ~top-third) with no gesture and no ⇧. Per CLAUDE.md a false positive is a
      release blocker. First step (owner's ask): add gesture logging to diagnose. DONE:
      `GestureRecognizer.diagnostic` opt-in side-channel emits one line per CONFIRMED
      decision (dir, action, dx/dy, progress, dt, speed, fingers, cmd, shift) — keeps
      the pure logic, zero cost when nil; threaded via `GestureEngine.onDiagnostic` →
      AppDelegate → debug log; `route` also logs the executed command. 3 TDD tests.
      → RESOLVED 2026-07-09/10 by log review: every confirmed gesture fire in the
      logs was a legitimate 3-finger stroke (all `fingers=3`, plausible dir/action/
      speed) — NO false positive was ever captured. The one suspicious window move
      (Telegram → half-monitor on monitor reconnect, 6.5) was proven to be macOS's
      own tiling, not Tiler: Tiler has no display-change handler and logged no
      `window …` line for it. Blocker cleared.
- [x] 6.2 Auto-log all sleep blockers (owner: less manual `pmset`): `SystemPower
      .sleepBlockers()` (parses `pmset -g assertions` holder lines) logged at
      launch/wake/sleep-wake/screen-sleep/after-release with the `SleepDisabled` flag —
      so "why won't it sleep" is captured automatically. Verified: launch line shows
      powerd/runningboardd/coreaudiod holders. Spec power diagnostic-logging updated.
- [x] 6.3 Idle-state log (owner puzzle: nothing should hold a CLOSED lid awake, yet the
      Mac didn't sleep after expiry). A 30 s `state lid=… power=… sleepDisabled=…
      blockers=N` tick runs only while debug logging is on and no session is active
      (heartbeat covers active sessions); when the lid is closed it also lists the
      holders. So the post-expiry period is continuously visible: ticks continuing =
      awake (+ who holds it), a gap = it slept. This will resolve whether the residual
      not-sleeping is Tiler's ~10 s restore window or a genuine external holder.
      → RESOLVED 2026-07-09 by the owner's isolation test: a fresh lid-close (no session)
      SLEPT cleanly (`system willSleep` + a 22-min gap in the 30 s ticks + battery
      51%→51% no drain + `didWake`; owner misread the instant lid-open wake as "never
      slept", CPU graph confirms). The audio assertion does NOT hold a closed lid. The
      real issue is only the clamshell-EXPIRY case (lid already closed) → handled by 6.4.
- [x] 6.4 Auto-sleep on lid-closed clamshell end (owner-approved). When a clamshell
      session ends by timer expiry or battery floor (not user Stop) with the lid still
      closed, Tiler sleeps the Mac once the watchdog restored the flag (poll
      disablesleep→0, re-check lid still closed, then `SystemPower.sleepNow()` =
      `osascript tell System Events to sleep`, no root). Bails if the user opens the lid.
      CAVEAT: first use prompts for the Automation (System Events) permission.
- [x] 6.5 Window-action logging (owner: a Telegram window moved to a non-Tiler-looking
      position on monitor reconnect — does the log catch it?). Confirmed Tiler has NO
      display-change handler (never repositions on screen change). `execute()` is the
      single chokepoint for every window move (gesture + hotkey); it now logs
      `window <cmd> src=gesture|hotkey ok=<b>` — a move with no such line is provably not
      Tiler. Spec power diagnostic-logging updated. Owner confirmed the Telegram move was
      macOS's own tiling on monitor disconnect (not Tiler).
- [x] 6.6 Round-2 polish (owner): (a) the lid-closed dialog gains an orange warning
      Label that a system Automation prompt may appear (the auto-sleep uses System
      Events on first use); (b) debug log rotation raised to ~100 MB × 1 backup
      (~200 MB) so detailed logging can run without worry.
