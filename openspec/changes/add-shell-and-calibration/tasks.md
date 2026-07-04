# Tasks — add-shell-and-calibration

Rules unchanged: TDD for pure logic, checkboxes updated as work happens, commit+push
per phase, `[USER GATE]` = owner touchpoints.

## 1. Right-swipe diagnosis & default retune

- [ ] 1.1 **[USER GATE #1]** Owner records a rights-only trace (~10 natural right
      swipes + 5 deliberate diagonals): `Scripts/record-golden.sh
      Tests/TilerCoreTests/Fixtures/rights-YYYYMMDD.jsonl` (any steps may be skipped
      with Enter — only the right-swipe and diagonal steps matter).
- [ ] 1.2 TraceCheck + per-episode angle/speed/assembly analysis: identify exactly why
      misses fail (angle > 37.6°? speed? assembly window? reversal?). Retune defaults
      if the data allows without touching blocker behavior; regenerate golden
      expected files; all tests green.
- [ ] 1.3 Commit "rights diagnosis + retune".

## 2. App identity: icon, About, menu

- [ ] 2.1 **[USER GATE #2]** Owner picks one of 3 proposed icon concepts (done in chat).
- [ ] 2.2 Icon pipeline: render chosen concept to .icns via Swift/CoreGraphics script
      (Scripts/make-icons.swift) at build; template menu-bar icon (normal + alert
      variants) replaces the text glyph.
- [x] 2.3 make-app.sh: build timestamp (TilerBuildDate) embedded; version 0.2.0.
      CFBundleIconFile lands with 2.2 once the owner picks a concept.
- [x] 2.4 About window (SwiftUI): icon, name, version, build time (TilerBuildDate,
      falls back to "dev build" for swift run), GitHub link. Headless smoke via
      --show-about.
- [x] 2.5 Menu restructure per spec: About / Settings… (⌘,) / Quit; ▦⚠︎ alert glyph
      until the real icon lands. Diagnostics + Launch at Login + permission line
      moved into Settings.
- [ ] 2.6 Commit "app identity".

## 3. Settings window

- [x] 3.1 SettingsStore (TDD: 4 tests, RED verified): persisted gestures/hotkeys
      toggles, injected UserDefaults suite, change notifications, no spurious
      events. Tunables overrides arrive with Phase 4.
- [x] 3.2 HotkeyController idempotent register/unregister (isRegistered) wired to
      the toggle; expiry timer cancelled on unregister. Release-to-system E2E check
      deferred to 5.2 (needs a quiet machine).
- [x] 3.3 Settings window (SwiftUI Form): toggles, permission row with red highlight
      + Settings deep link, Launch at Login (SMAppService with soft-fail revert),
      conflicts section (live ConflictDiagnostics), calibration entry (disabled until
      Phase 4). Headless smoke via --show-settings.
- [x] 3.4 Startup flow: launch without permission auto-opens Settings with the
      highlighted row (runStartupPermissionFlow). Verified by code path + smoke logs;
      full unpermitted-launch E2E folds into 5.2 acceptance.
- [ ] 3.5 Commit "settings".

## 4. Calibration

- [ ] 4.1 CalibrationSession (TilerCore, TDD): consumes TouchFrames + recognizer
      verdicts per prompted gesture; computes per-attempt recognized/missed, running
      accuracy, and suggested tunables (dominance cones from measured angle
      distributions, clamped to safe ranges); records session JSONL trace.
- [ ] 4.2 Safe-range clamps defined + regression proof: golden blocker fixtures must
      yield zero actions at ANY in-range tunables (property test over clamp corners).
- [ ] 4.3 Calibration UI (SwiftUI sheet from Settings): per-gesture mini animation
      (Canvas/keyframe, no assets), attempt counter, live success/accuracy animation,
      progress; apply/save/reset-to-defaults.
- [ ] 4.4 Live tunables application: recognizer swaps tunables only from clean idle
      (spec scenario) — unit test.
- [ ] 4.5 **[USER GATE #3]** Owner runs calibration; verify their right swipe reaches
      reliable detection; blocker acceptance re-run (scrolls move nothing).
- [ ] 4.6 Commit "calibration".

## 5. Wrap-up

- [ ] 5.1 README + acceptance checklist updates (Settings/About/calibration).
- [ ] 5.2 Full suite + Scripts/run-acceptance.sh green; golden fixtures re-frozen if
      tunables changed.
- [ ] 5.3 Archive change, merge deltas into openspec/specs/, update project.md, push.
