# Design — fix-script-launch-isolation

## Who may be touched

| Running copy | Before | After |
|---|---|---|
| This checkout's `build/Tiler.app` (the script's copy) | owner's settings + debug log; stopped by substring pattern | launch arguments (log off, gestures off); stopped by exact absolute path |
| Owner's installed copy (`~/Applications`) | untouched, but both copies act on swipes | untouched; the only copy that acts on swipes |
| Another checkout's / worktree's build | stopped by the substring pattern | untouched |

## Unit: `Scripts/lib/build-copy.zsh` (new, sourced)

One purpose: how a developer script runs this checkout's build without touching
the owner's Tiler. Sourced by zsh scripts after they `cd` to the repository root
(both scripts already do `cd "$(dirname "$0")/.."`). Sourcing only defines the
names below; it starts, stops and checks nothing.

| Name | Kind | Contract |
|---|---|---|
| `TILER_BUILD_BIN` | variable | `${PWD:A}/build/Tiler.app/Contents/MacOS/Tiler` — absolute, symlinks resolved, computed when sourced. The only path the scripts launch. |
| `TILER_BUILD_PATTERN` | variable | `^` + `TILER_BUILD_BIN` with every ERE metacharacter (`.[]()*+?{}|^$\`) backslash-escaped + `( \|$)`. Matches a command line whose argv[0] is exactly that path, with or without arguments; never a longer path, another checkout, or a relative launch. |
| `TILER_ISOLATED_ARGS` | array | `(-powerDebugLogging '<false/>' -gesturesEnabled '<false/>')` |
| `tiler_build_running` | function | status 0 iff a process matches `TILER_BUILD_PATTERN` (`pgrep -f`), else 1. |
| `tiler_stop_build` | function | `pkill -f "$TILER_BUILD_PATTERN"`, then waits until `tiler_build_running` is false (poll 0.1 s, up to 3 s). Always returns 0 — safe under `set -e` with nothing running. |
| `tiler_sleep_disabled` | function | status 0 iff `pmset -g` reports `SleepDisabled 1` — the same source as the app's `DisableSleepGovernor.sleepDisabledNow()` and the E2E guard. The test seam: the self-test redefines it after sourcing. |
| `tiler_require_sleep_enabled` | function | if `tiler_sleep_disabled`: prints `REFUSED: sleep is disabled (pmset SleepDisabled 1) — every launch would open the "Sleep is still disabled" alert; run again after the lid-closed session ends or the flag is restored.` to stderr and `exit 2`; else returns 0. |

Exit status 2 separates "did not run" from "ran and failed" (1); a refusal is
never a pass.

### Why the anchored pattern

`pgrep`/`pkill -f` match an extended regex against the space-joined argv. The
old `build/Tiler.app/Contents/MacOS/Tiler` substring also matched other
checkouts' builds (absolute or relative launches). Decoy probe 2026-10-14
(compiled sleeper binaries at `<tmp>/a/build/…`, `<tmp>/b/a/build/…`, plus
relative launches): the anchored, escaped absolute path stopped exactly the two
`<tmp>/a` copies (with and without arguments); the old pattern matched all
others. `( |$)` keeps `…/Tiler` from matching `…/Tiler2`.

## Settings without writes

`UserDefaults.standard` searches the argument domain first; values parsed from
argv are process-local and never persisted. `<false/>` arrives as a Bool (a bare
`NO` would arrive as a String, which `SettingsStore`'s `as? Bool` ignores).
Probe 2026-10-14 (macOS 27, Swift 6.4): the pairs parse as Bool whatever their
position relative to `--show-guide`, `--exercise-ui` and `--record-touches
<path>` (the latter becomes a harmless process-local key `-record-touches`). The
scripts still put the pairs first, for readability.
`fix-e2e-test-isolation` verified on the real build that a launch with
arguments writes neither the plist nor the debug log.

Effect per setting:

- `powerDebugLogging = false` → `PowerDebugLog` disabled: no `launch`,
  `touch stream`, `gesture` or `state` lines, and no 30 s debug-state timer.
- `gesturesEnabled = false` → `AppDelegate.route(_:)` drops every recognized
  action before any window command. Upstream of it, `GestureEngine.handle`
  appends every frame to the `--record-touches` recorder, and the touch stream
  starts as before (run-acceptance still sees `touch stream started`). Side
  effect limited to the script's copy: its own menu bar icon hides conflict
  marks (gated on `gesturesEnabled`).

Residual write, accepted: at launch `SettingsStore.deepSleepOnBattery` is set to
the `pmset` reality and persists only when the stored intent disagrees — the same
correction the owner's copy makes at its next launch.

## Script changes

`Scripts/run-acceptance.sh`:
- `source Scripts/lib/build-copy.zsh`; `tiler_require_sleep_enabled` before the
  build, so a refusal is immediate.
- `BIN` is replaced by `TILER_BUILD_BIN`; each launch becomes
  `"$TILER_BUILD_BIN" "${TILER_ISOLATED_ARGS[@]}" [app flags]`.
- Every `pkill -f "$BIN" …; sleep 0.5` becomes `tiler_stop_build`; the orphan
  check `pgrep -f "$BIN"` becomes `tiler_build_running`.
- `kill "$PID"` / `kill -9 "$PID"` lines, checks, labels and timings unchanged.

`Scripts/record-golden.sh`:
- Same source / guard / launch / stop changes; the launch is
  `"$TILER_BUILD_BIN" "${TILER_ISOLATED_ARGS[@]}" --record-touches "$OUT"`.
- `tiler_stop_build` returns 0, which removes the silent `set -e` exit.
- One added line before the steps: `This copy only records (gestures off): windows
  move only if your installed Tiler is running.`

## Behavior that must survive

- run-acceptance.sh: sections 1–4 with the same PASS/FAIL labels, the AX INFO
  line, `ACCEPTANCE: ALL PASS` / `ACCEPTANCE: FAILURES PRESENT`, exit 0/1, the
  `IDLE_SECONDS` override. New: exit 2 with the `REFUSED:` line.
- record-golden.sh: the optional output-path argument and its default
  (`Tests/TilerCoreTests/Fixtures/golden-<timestamp>.jsonl`), the 12 prompted
  steps, the final `Recorded N frames to …` line. New: exit 2 with `REFUSED:`.

## Verification plan

The repo has no shell test harness (and shellcheck does not support zsh), so:

1. `Scripts/lib/build-copy-test.zsh` — a self-test with compiled decoys in a
   temp dir (`cc`, from the Xcode toolchain already used for builds), written
   before the helper. It is the TDD loop for the helper's logic.
2. `zsh -n` on all four files.
3. Live run of `Scripts/run-acceptance.sh` with the owner's installed copy
   running: the owner's copy keeps its PID; a power assertion it held is still
   held; `power-debug.log` gains no `launch v` line (the owner's copy keeps
   writing its own `alive` lines, so only `launch v` lines are counted); the
   `pro.amilabs.tilerx` export is byte-identical before/after (a difference is
   diffed and reported, not hidden).
4. Non-interactive run of `Scripts/record-golden.sh` (12 newlines on stdin, out
   path in the scratch dir): it gets past the build, the trace file exists, its
   copy is gone afterwards, the same log/plist/installed-copy checks hold.
5. Gates: `swift build && swift test`, `swift format lint --recursive --strict
   Sources`, `Scripts/check-english.sh`.
