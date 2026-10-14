# Tasks — fix-script-launch-isolation

Owner decisions 2026-10-14 (translated): (a) debug log off + no gestures for the
script's copy; (b) stop by the exact path of this checkout; (c) don't touch the
installed copy; (d) refuse to start while sleep is disabled. No spec delta
(developer scripts only).

Global constraints (every task includes them):
- zsh scripts (`#!/bin/zsh`); everything committed is English (public repo;
  `Scripts/check-english.sh` before any push).
- No script stops, parks or relaunches any Tiler copy other than this checkout's
  build (decision c).
- Launch arguments use the plist form `<false/>`; a bare `NO` arrives as a
  String and is ignored by `SettingsStore`'s `as? Bool`.
- No new installs or dependencies.
- Commit locally; push only on the owner's go-ahead.

- [x] 1. Self-test first: `Scripts/lib/build-copy-test.zsh` (red while the helper
      is absent). Builds a sleeper decoy with `cc` in a `mktemp -d` dir (removed by
      a trap) and copies it to `<tmp>/t.e+s(t) x/build/Tiler.app/Contents/MacOS/Tiler`
      (regex metacharacters and a space in the path), `<tmp>/other/build/…`, and
      `<tmp>/t.e+s(t) x/build/Tiler.app/Contents/MacOS/Tiler2`. Sources the helper
      from `<tmp>/t.e+s(t) x` and asserts:
      - `TILER_BUILD_BIN` is the absolute path of that checkout's build;
      - `TILER_ISOLATED_ARGS` is exactly
        `(-powerDebugLogging '<false/>' -gesturesEnabled '<false/>')`;
      - `tiler_build_running` is 0 with an own copy running (with and without
        arguments) and 1 with only the others running;
      - `tiler_stop_build` stops both own copies and leaves the other checkout's
        build, a relative launch from `<tmp>/other`, and `Tiler2` alive;
      - `tiler_stop_build` returns 0 under `set -e` with nothing to stop;
      - with `tiler_sleep_disabled` redefined to return 0,
        `tiler_require_sleep_enabled` exits 2 and prints a line starting with
        `REFUSED:` to stderr; redefined to return 1, it returns 0.
      Prints `PASS:`/`FAIL:` lines and exits non-zero on any failure; kills every
      decoy it started.
      Produces: the executable spec for task 2.
- [x] 2. Helper `Scripts/lib/build-copy.zsh` per design.md (names and contracts
      exactly: `TILER_BUILD_BIN`, `TILER_BUILD_PATTERN`, `TILER_ISOLATED_ARGS`,
      `tiler_build_running`, `tiler_stop_build`, `tiler_sleep_disabled`,
      `tiler_require_sleep_enabled`); header comment names its consumers and that
      `-powerDebugLogging <false/>` mirrors
      `TilerCopies.isolatedLaunchArguments`. Task 1 green.
      Consumes: task 1. Produces: the names above for tasks 3–4.
- [x] 3. `Scripts/run-acceptance.sh`: source the helper after the `cd`; call
      `tiler_require_sleep_enabled` before `make-app.sh`; replace `BIN` with
      `TILER_BUILD_BIN`; launch every instance as
      `"$TILER_BUILD_BIN" "${TILER_ISOLATED_ARGS[@]}" [app flags]`; replace each
      `pkill -f "$BIN" 2>/dev/null; sleep 0.5` with `tiler_stop_build` and the
      orphan check's `pgrep -f "$BIN"` with `tiler_build_running`. Header comment:
      the script's copy never writes the owner's log, never acts on gestures,
      and the script refuses (exit 2) while sleep is disabled. Checks, labels,
      timings and `kill "$PID"` lines unchanged. `zsh -n` clean.
      Consumes: task 2.
- [ ] 4. `Scripts/record-golden.sh`: source the helper; guard before the build;
      launch `"$TILER_BUILD_BIN" "${TILER_ISOLATED_ARGS[@]}" --record-touches "$OUT"`;
      stop via `tiler_stop_build`; print `This copy only records (gestures off):
      windows move only if your installed Tiler is running.` before the steps.
      Steps, prompts, output-path argument and final line unchanged. `zsh -n` clean.
      Consumes: task 2.
- [ ] 5. Live verification of `Scripts/run-acceptance.sh` with the owner's
      installed copy running (`IDLE_SECONDS=20` is enough; 20 s is the documented
      minimum window). Record before/after: the installed copy's PID; whether it
      holds a power assertion (`pmset -g assertions`); the count of `launch v`
      lines in `~/Library/Logs/Tiler/power-debug.log`; a hash of
      `defaults export pro.amilabs.tilerx -`. Pass = `ACCEPTANCE: ALL PASS`, same
      PID, assertion still held if it was (unless the owner's log shows the
      session ending on its own schedule), no new `launch v` line, identical hash
      (any difference is diffed and reported). The refusal path is covered by
      task 1 (sleep is never disabled on purpose for this).
- [ ] 6. Non-interactive verification of `Scripts/record-golden.sh`: 12 newlines
      on stdin, output path in the scratch dir. Pass = it reaches `Recorded N
      frames` (N may be 0 without touches), the trace file exists, no own copy
      runs afterwards, and the task 5 log/plist/installed-copy checks hold.
- [ ] 7. Gates: `swift build && swift test`; `swift format lint --recursive
      --strict Sources`; `zsh -n` on the four scripts; `Scripts/lib/build-copy-test.zsh`;
      `Scripts/check-english.sh`.
- [ ] 8. Docs: `openspec/project.md` build/test notes — one paragraph: the two
      scripts launch the build by absolute path with log off / gestures off,
      never touch the installed copy, and refuse (exit 2) while sleep is
      disabled. Commit locally. (Archiving and the active-change lines move at
      acceptance, together with `fix-e2e-test-isolation`.)

No `[USER GATE]`: every verification above runs without the owner. The next
real golden recording confirms frames arrive with gestures off (code-level
evidence: `GestureEngine.handle` appends each frame before routing).
