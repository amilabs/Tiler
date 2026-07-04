# Tasks — add-shell-and-calibration

Rules unchanged: TDD for pure logic, checkboxes updated as work happens, commit+push
per phase, `[USER GATE]` = owner touchpoints.

## 1. Right-swipe diagnosis & default retune

- [x] 1.1 **[USER GATE #1 PASSED]** (frictionless path: Claude ran the recorder in
      the background, owner just swiped). rights-20260704.jsonl: 13 natural rights,
      7 lefts, 9 ups, 4 diagonals, 3 finger-rest sessions; 4308 frames.
- [x] 1.2 Analysis: lefts (163–179°) and ups (87–92°) flawless; rights tilt +10…+40°
      with one 40.1° miss at dominance 1.19, plus one +66° outlier (geometrically an
      up-swipe; calibration UI will surface it). Speed/assembly/duration all clean.
      Retuned horizontalDominance 1.3 → 1.15 (= calibration floor, already
      blocker-proven by corner property tests). Rights trace frozen as a second
      golden fixture (20 expected actions); main golden regenerated (47).
- [x] 1.3 Commit "rights diagnosis + retune".

## 2. App identity: icon, About, menu

- [x] 2.1 **[USER GATE #2 PASSED]** Owner iterated through 4 concept rounds and picked
      catalog glyph #6 (hand.pinch.fill) as-is; custom pinch art rejected. SF-Symbol-in-
      app-icon license caveat flagged and accepted for this private build (revisit
      before any public distribution).
- [x] 2.2 Icon pipeline: make-icons.swift renders hand.pinch.fill on the violet
      squircle to .icns at build (make-app.sh embeds CFBundleIconFile + Resources);
      menu bar shows the same symbol as a template image with a ⚠︎ suffix when
      Accessibility is missing.
- [x] 2.3 make-app.sh: build timestamp (TilerBuildDate) embedded; version 0.2.0.
      CFBundleIconFile lands with 2.2 once the owner picks a concept.
- [x] 2.4 About window (SwiftUI): icon, name, version, build time (TilerBuildDate,
      falls back to "dev build" for swift run), GitHub link. Headless smoke via
      --show-about.
- [x] 2.5 Menu restructure per spec: About / Settings… (⌘,) / Quit; ▦⚠︎ alert glyph
      until the real icon lands. Diagnostics + Launch at Login + permission line
      moved into Settings.
- [x] 2.6 Commit "app identity".

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
- [x] 3.5 Commit "settings".

## 4. Calibration

- [x] 4.1 CalibrationSession (TilerCore, TDD: 8 tests, RED verified): prompt
      progression, per-attempt recognized/missed with measured angle, noise attempts
      not consumed, step accuracy, suggested dominance from the most-demanding
      attempt ×0.95 margin (floor/ceiling clamps), frames recorded for diagnostics.
- [x] 4.2 Clamp ranges (horizontal 1.15…2.0, vertical 1.35…2.2) + corner property
      tests: golden 190 s blocker window silent, synthetic blockers silent, canonical
      swipes still fire — at all 4 corners.
- [ ] 4.3 Calibration UI (SwiftUI sheet from Settings): per-gesture mini animation
      (Canvas/keyframe, no assets), attempt counter, live success/accuracy animation,
      progress; apply/save/reset-to-defaults.
- [x] 4.4 GestureRecognizer.updateTunables: staged, applied only from clean idle —
      mid-gesture swap keeps old values (unit tests both ways).
- [ ] 4.5 **[USER GATE #3]** Owner runs calibration; verify their right swipe reaches
      reliable detection; blocker acceptance re-run (scrolls move nothing).
- [ ] 4.6 Commit "calibration".

## 5. Wrap-up

- [ ] 5.1 README + acceptance checklist updates (Settings/About/calibration).
- [ ] 5.2 Full suite + Scripts/run-acceptance.sh green; golden fixtures re-frozen if
      tunables changed.
- [ ] 5.3 Archive change, merge deltas into openspec/specs/, update project.md, push.
