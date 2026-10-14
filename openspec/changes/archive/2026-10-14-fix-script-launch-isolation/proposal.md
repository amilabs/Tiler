# fix-script-launch-isolation

Designed on: Opus 5.5, default effort, default stance (light tooling follow-up to
`fix-e2e-test-isolation`).

## Why

`fix-e2e-test-isolation` isolated the Hotkey E2E from the owner's Tiler. The two
developer scripts that launch this checkout's `build/Tiler.app` still are not
isolated (all facts checked 2026-10-14):

1. **They write the owner's diagnostic log.** `Scripts/run-acceptance.sh` and
   `Scripts/record-golden.sh` launch the build with no settings of their own, so
   it reads the owner's `pro.amilabs.tilerx` domain. The owner has
   `powerDebugLogging = 1`, so every acceptance run appends five launch blocks
   (`launch v…`, touch-stream devices, sleep blockers) to
   `~/Library/Logs/Tiler/power-debug.log`. With debug logging on, each instance
   also runs the 30 s debug-state timer while its idle CPU is measured.
2. **Their copy acts on the owner's input.** The owner's installed copy normally
   runs alongside (it did, holding a live Prevent Sleep session). Both copies
   recognize every 3-finger swipe and both execute the window command; with ⌘
   held (`nextDisplay`) each copy moves the window to the next display (read
   from the code, not reproduced). `record-golden.sh` asks the owner for exactly
   these swipes.
3. **Their pkill is too wide.** `pkill -f "build/Tiler.app/Contents/MacOS/Tiler"`
   is a substring match: it also stops the build of any other checkout or
   worktree, launched relatively or by absolute path (e.g. a concurrent E2E in
   another worktree). It never matches `~/Applications/Tiler.app` (no `build/`
   segment). Verified on decoy processes. The "no orphan after kill -9" check
   uses the same pattern, so another checkout's running build fails it falsely.
4. **`record-golden.sh` never gets past the build.** Under `set -e`, `pkill` with
   no match returns 1 and ends the script silently right after `make-app.sh` —
   the normal case, since no build copy is running. Reproduced.
5. **Disabled sleep turns every launch into a trap.** While `pmset -g` reports
   `SleepDisabled 1` (a lid-closed session armed, or a leftover flag), each
   launched instance opens the modal "Sleep is still disabled" alert with a
   "Restore normal sleep" button — five alerts per acceptance run, and one click
   ends the owner's lid-closed session.

## What

Owner decisions 2026-10-14 (translated; the four recommended options):
(a) "debug log off + no gestures"; (b) "exact path of this checkout";
(c) "don't touch" the installed copy; (d) "refuse to start".

- A sourced helper, `Scripts/lib/build-copy.zsh`, owns how a script runs this
  checkout's build: the absolute executable path, exact-path lookup and stop,
  the isolating launch arguments, and the sleep-disabled guard. Both scripts use
  it; a self-test pins its matching logic.
- The script's copy is launched with `-powerDebugLogging <false/>
  -gesturesEnabled <false/>` (the argument domain: process-local, never
  persisted). Nothing reaches the owner's debug log, and the copy never moves a
  window. Its touch stream and the `--record-touches` recorder keep running, so
  recording still captures every frame. Hotkeys keep the owner's stored values.
- Lookup and stop match only this checkout's build: the anchored, regex-escaped
  absolute executable path. Every launch uses that absolute path.
- Both scripts refuse to start while sleep is disabled: exit status 2 and one
  `REFUSED:` line naming the reason.
- `record-golden.sh` no longer exits after the build when nothing is running,
  and tells the owner that its copy only records.
- The owner's installed copy is never stopped, parked or relaunched by these
  scripts; a live Prevent Sleep session continues through a run.

## Risk profile

`build-deploy` — developer scripts only; no product code, no new dependency.
Mandatory verification: the scripts run end to end; `swift build && swift test`
and `swift format lint --recursive --strict Sources` stay clean. /code-review
effort: medium.

No spec delta: `openspec/specs/` does not cover developer scripts (same as
`fix-e2e-test-isolation`). Brownfield modifier: the two scripts have no code
dependents (they are referenced only from docs), so no blast-radius run is needed.

## Approach and rejected alternatives

- **Chosen:** launch arguments + exact-path matching + refuse on
  `SleepDisabled 1`, defined once in a sourced helper used by both scripts.
- Rejected: park and relaunch the installed copy like the E2E — owner decision
  (c); it would end live Prevent Sleep sessions or force a refusal, and needs a
  shell port (or a CLI) of `TilerCopies`' park/relaunch/sentinel. The passive
  copy already removes the interference.
- Rejected: inline fixes in each script — two copies of the regex escaping and
  the guard would drift apart.
- Rejected: stop launched PIDs only, no pattern — leftovers of an interrupted
  earlier run (the reason the scripts stop copies first) have no PID on record.
- Rejected: write the owner's settings and restore them afterwards — the owner's
  copy runs meanwhile and may write too; the argument domain needs no restore.

## Out of scope

- `Scripts/install.sh` still stops every copy by pattern — it replaces the
  installed app on purpose.
- `Scripts/power-acceptance.sh` runs the bare debug binary `.build/debug/Tiler`,
  whose settings domain is `Tiler` (it holds only `hasSeenGuide`), not
  `pro.amilabs.tilerx`, so it does not write the owner's log. Unchanged.
- The script copy's hotkeys stay as stored. With the installed copy running,
  both copies try to register ⌃A; the acceptance check "hotkeys configured" is a
  log line that does not prove registration (pre-existing weakness, unchanged).
- `TilerCopies.isolatedLaunchArguments` (the E2E's set) stays as is: the E2E
  needs window hotkeys on and keeps gestures on. Only `-powerDebugLogging
  <false/>` is shared; the helper's comment points at it.
- A copy launched by an older version of these scripts via the relative path is
  not matched by the new stop (transitional: only a leftover from a run before
  this change).

## Impact

New `Scripts/lib/build-copy.zsh` and `Scripts/lib/build-copy-test.zsh`; changed
`Scripts/run-acceptance.sh`, `Scripts/record-golden.sh`; `openspec/project.md`
build/test notes and the CLAUDE.md active-change line. No product code, no
release. Depends on `fix-e2e-test-isolation` (this branch carries its commits,
including the `make-app.sh` fix without which neither script builds under
Swift 6.4).
