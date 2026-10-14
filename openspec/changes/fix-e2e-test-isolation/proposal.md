# fix-e2e-test-isolation

## Why

2026-10-14: the owner's installed Tiler (`~/Applications/Tiler.app`) was found
not running. Its debug log stopped at 11:18Z (13:18 local) right after eleven
test-launched `launch v0.3.6` lines from `swift test` runs in the main checkout.
Three defects in the "Hotkey E2E" suite of
`Tests/TilerIntegrationTests/AXSystemTests.swift`, all reproducible from the code:

1. **It killed the owner's app.** `launchTiler()` ran
   `pkill -f Tiler.app/Contents/MacOS/Tiler`. The pattern also matches
   `~/Applications/Tiler.app/Contents/MacOS/Tiler`, so every `swift test` on an
   AX-trusted host killed the installed copy (and with it any live Prevent Sleep
   session), and nothing restarted it.
2. **A fresh checkout failed instead of skipping.** Without `build/Tiler.app`
   (any new git worktree) the four E2E tests failed with "The file 'Tiler'
   doesn't exist" — after the pkill had already run.
3. **It leaked into the owner's settings.** To enable window hotkeys for the
   instance under test it wrote `windowHotkeysEnabled = true` into the real
   `pro.amilabs.tilerx` domain and restored it 0.9 s later — but the restore was
   skipped whenever `process.run()` threw (defect 2). A run in a fresh worktree at
   11:29Z (13:29 local; the plist mtime matches) left the key `true`; the owner's
   Tiler, relaunched at 11:58Z, came up with ⌃⇧-arrow hotkeys grabbed. The log
   shows the owner never used window hotkeys in three months (only ⌃A), so the
   key was restored to its original state (absent = OFF) on 2026-10-14.
   The instance under test also wrote its `launch` lines into the owner's
   diagnostic log, which muddied the incident analysis.

## What

Test harness only; no product code or spec changes.

- The E2E suite is **gated on the build existing** — a fresh checkout skips it
  with a reason instead of failing.
- The suite **stops only the build it launched** (exact executable match), never
  a copy by name pattern.
- The instance under test gets its settings from **launch arguments** (the
  volatile argument domain): window hotkeys on, debug logging off. Nothing is
  written to the owner's settings, so there is nothing to restore.
- Owner decision 2026-10-14 (translated: "close and relaunch"): for the suite's
  duration every other running Tiler copy is **parked** (quit) and then
  **relaunched**, so only the build under test holds the hotkeys. A detached
  sentinel relaunches the parked copies even if the test process crashes or is
  killed (Ctrl-C, a tool timeout).
- The suite is **skipped, never parked**, while another copy holds a live
  Prevent Sleep session (any power assertion) or sleep is disabled — ending the
  owner's session is not an acceptable test side effect.
- Owner rule 2026-10-14 (translated): "after tests, settings must be returned to
  their original state."

## Impact

`Tests/TilerIntegrationTests/` only (new `TilerCopies.swift` helper + its tests;
`AXSystemTests.swift` E2E suite). `openspec/project.md` build/test notes. No
release.
