# Tasks — add-tiler-mvp

Rules: TDD for phases 2–5 (test first). Update checkboxes **as work happens**, not after.
Every phase ends with a commit + push. `[USER GATE]` = the only points needing the owner.

## 1. Scaffolding & probes

- [ ] 1.1 SwiftPM executable package `Tiler` (Swift 6.3, macOS 26 platform), module layout:
      `TilerCore` (pure logic: recognizer, tunables, models) + `Tiler` (app: AppKit,
      TouchStream, WindowActions, HotkeyController). `swift build && swift test` green.
- [ ] 1.2 `Scripts/make-app.sh`: assemble Tiler.app (Info.plist: LSUIElement=YES,
      CFBundleIdentifier `pro.amilabs.tiler`), codesign with "WindowGestures Local Dev".
      Verify: app launches, status item visible, `codesign -dv` shows the identity.
- [ ] 1.3 Minimal status item + Quit. Verify launch/quit cleanly via CLI (`open`, `pkill`).
- [ ] 1.4 **MT probe**: link MultitouchSupport, `MTDeviceCreateList` +
      `MTRegisterContactFrameCallback`; log device count and whether callback registers
      without extra TCC on macOS 26. Record findings in design.md §1. (Real-touch data
      requires a human finger — only registration success is self-verifiable here;
      full data check merges into gate 3.1.)
- [ ] 1.5 Commit "scaffolding + MT probe".

## 2. GestureRecognizer (pure FSM, TDD — core of the product)

- [ ] 2.1 Models: `Contact`, `TouchFrame`, `GestureAction`, `Tunables` (all initial
      values from design.md §2 table).
- [ ] 2.2 Test suite from gestures spec — every Scenario becomes a named test:
      stale/size-0 contacts, palm, 2→3→2, 3→4, 3→2, re-form without lift-off,
      diagonal ~30°, short/slow/jerky/reversed/timeout, momentum-after-liftoff,
      swipe-down no-op, Cmd variants, one-action-per-gesture, lockout/cooldown,
      exact-3 arming, direction dominance boundaries (26.5°/26.7°, 32°±).
- [ ] 2.3 Implement FSM until suite green. No system imports in `TilerCore`.
- [ ] 2.4 Fuzz test: randomized 1/2/4-finger noise streams × 10k frames → zero actions.
- [ ] 2.5 Commit "gesture recognizer + tests".

## 3. TouchStream + trace tooling

- [ ] 3.1 TouchStream wrapper (device attach/detach, frame normalization, background
      queue → recognizer). `--record-touches <path>` debug flag dumps raw frames as JSON.
      **[USER GATE #1]** Grant AX to the dev/test host when asked; then a short live
      sanity run: does the callback deliver frames (owner touches the pad once).
- [ ] 3.2 Trace replay: JSON → `TouchFrame` stream in tests (same path as synthetic).
- [ ] 3.3 Commit "touch stream + record/replay".

## 4. WindowActions (AX) + integration tests

- [ ] 4.1 AX layer per window-actions spec (focused window, screen resolution,
      halves/maximize/center-third geometry, restore store, next-display cycle,
      AXEnhancedUserInterface + size→position→size workarounds, soft AXError handling).
- [ ] 4.2 Integration tests (need AX on test host from gate #1): spawn TextEdit or a
      helper app window; apply each action; read frame back; assert geometry incl.
      visibleFrame respect and restore semantics. Single-display next-monitor fallback.
- [ ] 4.3 Commit "window actions + AX integration tests".

## 5. Hotkeys + permission lifecycle

- [ ] 5.1 HotkeyController: Carbon registration of all bindings; double-press ↑
      disambiguation (300 ms); unit tests for the disambiguation timer logic (abstracted
      clock).
- [ ] 5.2 PermissionMonitor per permissions spec (prompt once, poll 2 s only while
      missing, stop when granted, soft re-entry on revocation).
- [ ] 5.3 E2E: CGEventPost synthetic hotkey presses → assert window frames; single vs
      double press timing; no-op without permission (`tccutil reset Accessibility
      pro.amilabs.tiler` for the negative case — self-service).
      **[USER GATE #2]** One re-grant click after the negative test, verifying
      no-restart recovery (permissions spec scenario).
- [ ] 5.4 Commit "hotkeys + permission lifecycle".

## 6. App shell

- [ ] 6.1 Menu per app-shell spec: status/warning states, Settings-pane shortcut,
      gestures toggle, Launch at Login (SMAppService), version, Quit.
- [ ] 6.2 Diagnostics: read trackpad/dock defaults, list conflicts + guidance.
      Manual-check script `Scripts/diagnose.sh` mirrors it for CLI verification.
- [ ] 6.3 Commit "app shell + diagnostics".

## 7. Performance & resilience acceptance (self-service)

- [ ] 7.1 `Scripts/run-acceptance.sh`: 60 s idle CPU sampling (< 1% budget), kill -9 →
      system input unaffected → relaunch clean, launch-without-permission alive check.
- [ ] 7.2 Fix regressions until green; record results in this file.
- [ ] 7.3 Commit "acceptance harness + results".

## 8. Golden traces & real-gesture acceptance

- [ ] 8.1 **[USER GATE #3]** Owner records one trace session (`--record-touches`):
      2-finger scrolls (vert/horiz/diagonal + momentum) in Safari/Chrome/Finder,
      2→3→2 transitions, palm-resting, diagonal ~30° swipes, valid left/right/up swipes
      ×5 each, Cmd-variants. Script prompts step-by-step: `Scripts/record-golden.sh`.
- [ ] 8.2 Freeze traces as test fixtures; tune Tunables until all golden tests pass
      (false-positive fixtures MUST produce zero actions — blocker).
- [ ] 8.3 **[USER GATE #4]** Final manual acceptance on real trackpad (checklist printed
      by `Scripts/acceptance-checklist.sh`; system 3-finger gestures disabled first).
- [ ] 8.4 Commit "golden traces + tuning".

## 9. Wrap-up

- [ ] 9.1 README: install, permissions, conflicts/diagnostics guide, hotkey/gesture table.
- [ ] 9.2 Archive this change: move to `openspec/changes/archive/YYYY-MM-DD-add-tiler-mvp/`,
      merge spec deltas into `openspec/specs/`, update `openspec/project.md`.
- [ ] 9.3 Final commit + push.
