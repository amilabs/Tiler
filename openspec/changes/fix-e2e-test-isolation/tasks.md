# Tasks — fix-e2e-test-isolation

Owner context 2026-10-14 (translated): close and relaunch the installed Tiler
for the E2E; "after tests, settings must be returned to their original state";
a small change folder, no spec delta (test harness only).

- [x] 0. Restore the leaked `windowHotkeysEnabled` in the owner's domain to its
      original state (key absent = OFF; evidence: three months of logs show no
      window-hotkey use outside test runs). The running copy picks it up at its
      next launch.
- [x] 1. TDD `TilerCopies` pure logic: build-under-test matching (installed and
      other-checkout paths never match), power-assertion lookup by PID.
- [x] 2. TDD the sentinel: fires its command after the watched process exits,
      never after being disarmed, runs in its own session.
- [x] 3. E2E suite: build-exists gate, live-session guard, parking trait,
      exact-match stop of the build under test, launch-argument settings
      (no writes); a test that the build under test runs with window hotkeys
      on while the owner's stored values and debug log stay untouched.
- [x] 4. Verify (2026-10-14): `swift test` green (149 core + 55 integration;
      window AX suite ran; Hotkey E2E skipped with the live-session reason while
      the owner's Tiler held a Prevent Sleep session — that copy stayed up, same
      PID, before and after); build moved aside → skipped with the build reason;
      `swift format lint --recursive --strict Sources` and the new test files
      clean; Scripts/check-english.sh clean. Park/relaunch/sentinel verified on
      decoy apps with the real `TilerCopies` code (normal path, SIGKILL,
      process-group kill); launch arguments verified on the real build
      (`window: on` with the stored value OFF, no plist or debug-log writes).
- [ ] 4b. Live run of the full E2E with the owner's installed copy parked and
      relaunched — pending: needs a moment without a live Prevent Sleep session
      (any `swift test` on the owner's Mac then exercises it).
- [x] 5. `openspec/project.md` build/test notes; commit locally (push only on
      the owner's go-ahead).

Incidental (found while verifying, separate commit): `Scripts/make-app.sh` no
longer built `build/Tiler.app` under Swift 6.4 — the universal binary moved to
`.build/out/Products/Release`; the script now asks `--show-bin-path`.
