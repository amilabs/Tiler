# Tasks — add-tiler-mvp

Rules: TDD for phases 2–5 (test first). Update checkboxes **as work happens**, not after.
Every phase ends with a commit + push. `[USER GATE]` = the only points needing the owner.

## 1. Scaffolding & probes

- [x] 1.1 SwiftPM executable package `Tiler` (Swift 6.3, macOS 26 platform), module layout:
      `TilerCore` (pure logic: recognizer, tunables, models) + `Tiler` (app: AppKit,
      TouchStream, WindowActions, HotkeyController). `swift build && swift test` green.
- [x] 1.2 `Scripts/make-app.sh`: assemble Tiler.app (Info.plist: LSUIElement=YES,
      CFBundleIdentifier `pro.amilabs.tiler`), codesign with "WindowGestures Local Dev".
      Verified: `codesign -dv` shows Identifier=pro.amilabs.tiler, signed with the identity.
- [x] 1.3 Minimal status item + Quit. Verified: launches via `open`, process alive at
      0.0% CPU, exits cleanly on quit.
- [x] 1.4 **MT probe** (`Tiler --mt-probe`): dlopen/dlsym (framework is in dyld shared
      cache — no link-time linking), 1 device found (family 0x6e, 26×18), callback
      registration + MTDeviceStart succeed with no TCC prompt, no crash. Findings
      recorded in design.md §1. Live frame delivery deferred to gate 3.1.
- [x] 1.5 Commit "scaffolding + MT probe".

## 2. GestureRecognizer (pure FSM, TDD — core of the product)

- [x] 2.1 Models: `Contact`, `TouchFrame`, `GestureAction`, `Tunables` (all initial
      values from design.md §2 table).
- [x] 2.2 Test suite from gestures spec — every Scenario is a named test (47 tests,
      6 suites): stale/size-0, ended states, palm (incl. palm+3), 2→3→2, 3→4, 3→2,
      re-form without lift-off, scroll+late-third (new session rule), staggered
      touchdown positive, diagonal 28°/30°/55°/ambiguous band, short/slow/jerky/
      reversed/timeout/cancelled, momentum, swipe-down no-op, Cmd variants,
      one-action-per-gesture, lockout/cooldown, mutation guard for the session rule.
      RED verified: 15 positive tests failed against the nil stub before implementation.
- [x] 2.3 FSM implemented, suite green (47/47). No system imports in `TilerCore`.
      Spec strengthened during TDD: clean-session rule + `touchdownAssemblyWindow`
      (see gestures spec + design.md §2) — stable-frame counting alone did not block
      "third finger added mid-scroll".
- [x] 2.4 Fuzz: seeded non-3-finger noise (~10k+ frames) and ambiguous-angle sweeps
      (200 random swipes, 28°–56° band) → zero actions; positive harness control.
- [x] 2.5 Commit "gesture recognizer + tests".

## 3. TouchStream + trace tooling

- [x] 3.1 TouchStream wrapper: dlopen/dlsym, C-shim target `CMultitouchSupport` for the
      MTTouch layout, serial queue → GestureEngine → recognizer, `--record-touches`
      JSONL recorder. Smoke-verified: stream starts, recorder writes, clean exit,
      zero build warnings (Swift 6 concurrency-clean).
      Devices are enumerated at start; hotplug (Magic Trackpad attach) re-scan is
      deferred to Phase 6 diagnostics work.
      **[USER GATE #1 PASSED]** AX granted to the host; all AX integration + hotkey
      E2E tests run green. Live single-touch frame-delivery sanity folds into gate 3
      (golden recording) — still needs the owner's fingers.
- [x] 3.2 Trace replay: JSONL round-trip + replay parity tests (TraceIO in TilerCore);
      replayed trace reproduces identical actions. 50 tests green.
- [x] 3.3 Commit "touch stream + record/replay".

## 4. WindowActions (AX) + integration tests

- [x] 4.1 AX layer implemented (`TilerSystem/WindowActions.swift`): focused-window +
      max-intersection screen resolution, halves/maximize/center-third geometry off
      visibleFrame, restore store with manual-move re-capture, next-display cycle,
      AXEnhancedUserInterface clear/restore, size→position→size, Cocoa↔AX coordinate
      conversion, soft AXError handling, dead-window store trimming. Wired into the
      gesture pipeline (AppDelegate.route). Code restructured: new `TilerSystem`
      library target so tests can import the system layer.
- [x] 4.2 Integration tests (`Tests/TilerIntegrationTests/AXSystemTests.swift`):
      TextEdit target, all five commands + restore semantics + next-display, geometry
      read-back with 2 px tolerance. **GATE #1 PASSED** — AX granted to the host,
      all 6 window tests GREEN. Both AX suites nested under one `.serialized` parent so
      global-hotkey E2E never races the window suite for frontmost focus.
- [x] 4.3 Commit "window actions + AX integration tests".

## 5. Hotkeys + permission lifecycle

- [x] 5.1 HotkeyController: Carbon registration of all 6 bindings, EventHotKeyID
      routing, double-press ↑ via pure `DoublePressResolver` (TilerCore, TDD: 7 tests,
      RED verified against stub; abstracted clock = timestamps + injected expiry).
- [x] 5.2 PermissionMonitor per permissions spec (TDD: 4 tests, RED verified): injected
      trust check, poll only while missing, stops when granted, `noteActionFailed()`
      re-entry on revocation. Wired: launch prompt (once), status-item warning ▦⚠︎,
      WindowActions failures feed the monitor. Smoke: launch without AX → warning
      logged, hotkeys registered, stream alive, CPU 0.1%, clean exit.
- [x] 5.3 E2E: hotkey presses via System Events (CGEventPost does NOT reach Carbon
      RegisterEventHotKey on macOS 26 — discovered and documented; AppleScript key
      events do). 4 E2E tests green vs real Tiler.app + TextEdit: left half, single-up
      maximize after the 300 ms window (with the in-window no-move assertion), double-up
      center-third (never maximizes), restore. Revocation: `tccutil reset` → Tiler
      stays ALIVE, no crash (verified). NOTE: macOS caches AX trust inside an already-
      trusted running process (that's why it SIGKILLs GUI apps on reset; our CLI process
      kept its grant), so live in-process revocation detection can't be scripted — the
      warning/repoll transition is covered deterministically by PermissionMonitor unit
      tests. **[USER GATE #2 — remaining]** revoke via System Settings UI (triggers the
      OS kill/re-request) and one re-grant, eyeballing the ▦⚠︎ warning + no-restart
      recovery per the permissions spec.
- [x] 5.4 Commit "hotkeys + permission lifecycle".

## 6. App shell

- [x] 6.1 Menu per app-shell spec: permission status line + warning glyph ▦⚠︎,
      "Open Accessibility Settings…" deep link, Gestures Enabled toggle (gates the
      gesture route only, hotkeys untouched), Diagnostics submenu (rebuilt on open),
      Launch at Login (SMAppService, soft-fails unbundled), version, Quit.
- [x] 6.2 ConflictDiagnostics (TDD: 4 tests, RED verified; injected reader): Three
      Finger Drag + system 3-finger swipes across built-in and Bluetooth-trackpad
      domains. `Scripts/diagnose.sh` mirrors it for CLI. Owner's system verified
      clean — no conflicting gestures enabled (2026-07-04).
- [x] 6.3 Commit "app shell + diagnostics".

## 7. Performance & resilience acceptance (self-service)

- [x] 7.1 `Scripts/run-acceptance.sh`: launch health, 60 s idle CPU sampling, kill -9
      orphan/relaunch checks, without-permission alive path.
- [x] 7.2 Results (2026-07-04, unpermitted worst case — permission poll active):
      ALL PASS. Launch health ✓; idle CPU 12/12 samples < 1% (max 0.9%); kill -9 →
      no orphans, clean relaunch, hotkeys re-registered. CPU drops further once AX
      is granted (poll stops).
- [x] 7.3 Commit "acceptance harness + results".

## 8. Golden traces & real-gesture acceptance

- [x] 8.1 **[USER GATE #3 PASSED]** Owner recorded a 400 s / 18,880-frame session
      (2026-07-04, `golden-20260704-194040.jsonl`) covering all scripted steps. Live
      frame delivery + MTTouch field mapping confirmed (sane sizes/states/coords).
- [x] 8.2 Golden analysis + frozen fixture (`GoldenTraceTests`, expected sequence
      machine-generated via `TraceCheck --write-expected`; 35 actions):
      **zero actions across all blocker segments** (~250 s of scrolls, momentum,
      third-finger additions, 2→3→2, palm), no double-fires anywhere. Tunables kept
      at spec values — validated, no tuning needed. Boundary observations for the
      owner (per-spec behavior, not bugs): (a) steep "diagonals" at 60–68° from
      horizontal legitimately fire as up (vertical cone is ≤32° off vertical);
      (b) owner's natural right swipes tilt +25…+36° and ~half get strictly rejected
      at the 26.6° horizontal boundary — retunable via `horizontalDominance` if
      acceptance shows too many misses. New tool: `swift run TraceCheck <trace>`
      replays any recording with per-segment action reporting.
- [x] 8.3 **[USER GATE #4 PASSED]** (2026-07-04 late evening, owner: «все круто») —
      hotkeys, gestures, permission lifecycle accepted on the granted ~/Applications
      build. One carry-over defect, explicitly NOT a blocker (false negative, not
      false positive): **right swipe still under-detects** for the owner's hand even
      at horizontalDominance 1.3. Transferred to the next change
      (`add-shell-and-calibration`) — to be fixed by per-user gesture calibration
      plus a data-driven default retune from a fresh rights-only trace.
- [x] 8.4 Commit "golden traces + tuning".

## 9. Wrap-up

- [x] 9.0 **TCC enrollment saga resolved** (2026-07-04 evening): Accessibility row
      never persisted for self-signed builds (prompt shown, row silently dropped;
      System-keychain trust, ad-hoc, reboot — all ineffective). Working recipe:
      Apple Development signature (WWDR G3 intermediate had to be imported — the
      System-keychain copy expired 2023) + fresh bundle id `pro.amilabs.tilerx`
      (the original id's TCC client record is wedged on this machine). Grant now
      persists across rebuilds via `Scripts/install.sh`; verified `trusted=true`
      as own responsible process with zero prompts. Documented in README; scripts
      updated; gestures confirmed working by owner on the granted build.

- [x] 9.1 README: install, permissions, conflicts/diagnostics guide, hotkey/gesture table.
- [x] 9.2 Archived to `openspec/changes/archive/2026-07-04-add-tiler-mvp/`,
      merge spec deltas into `openspec/specs/`, update `openspec/project.md`.
- [x] 9.3 Final commit + push.
