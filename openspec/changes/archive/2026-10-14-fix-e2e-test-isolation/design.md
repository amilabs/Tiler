# Design — fix-e2e-test-isolation

## Who may be touched

| Running copy | Before | After |
|---|---|---|
| This checkout's `build/Tiler.app` (the build under test) | `pkill -f` by name | stopped by exact executable path; launched per test, terminated by `defer` |
| Owner's installed copy (`~/Applications`) | killed, never restarted | parked for the suite, relaunched after (or the suite skips, see below) |
| Another checkout's build | killed | parked and relaunched like any other copy |

"Other copy" = any running app with bundle id `pro.amilabs.tilerx` whose
executable is not this checkout's build. Parking all of them (not just
`~/Applications`) keeps the rule simple and restores exactly what was running.

## Settings without writes

`UserDefaults.standard` searches the argument domain first. Launching the build
with `-windowHotkeysEnabled <true/> -powerDebugLogging <false/>` overrides the
owner's values for that process only. Probe (2026-10-14): `-key YES` arrives as
the String "YES" (`as? Bool` is nil — SettingsStore reads `object(forKey:) as?
Bool`), while `-key <true/>` arrives as a Bool. Nothing is persisted, so a crash
can no longer leave the owner's settings changed. Debug logging is forced off so
test launches stay out of `~/Library/Logs/Tiler/power-debug.log`.

## Parking

A suite-scoped `TestScoping` trait (not recursive: one scope around the whole
suite):

1. Re-check the live-session guard (planning ran up to a minute earlier); if a
   session appeared meanwhile, throw — refuse to park, fail loudly.
2. Arm the sentinel with the other copies' bundles, then quit each copy
   (`NSRunningApplication.terminate()`; Tiler has no quit confirmation), wait up
   to 5 s for the PID to vanish (`kill -0`), then `forceTerminate()`.
3. Run the suite, stop leftovers of the build under test, relaunch every parked
   bundle, disarm the sentinel. A relaunch that does not come up is recorded as a
   test failure (the owner must learn their app is down).

Process state is read from the kernel (`kill -0`) and from fresh
`NSRunningApplication.runningApplications(withBundleIdentifier:)` queries:
`isTerminated` and `NSWorkspace.runningApplications` only refresh while a main
run loop spins, which the test runner does not guarantee.

LaunchServices probes on decoy app copies (2026-10-14, macOS 27):

- `NSWorkspace.openApplication(at:)` without `createsNewApplicationInstance`
  returns any running app with the same bundle id (e.g. the build under test) and
  starts nothing. Relaunch therefore sets the flag, and first filters out bundles
  already running from that path, so it never starts a second instance.
- The `open` CLI matches by bundle path: `open -g <copy>` starts that copy even
  while another copy with the same bundle id runs, and does nothing if that copy
  already runs. The sentinel relies on this.
- Untyped, `try await NSWorkspace.shared.openApplication(at:configuration:)`
  resolves under Swift 6.4 to the fire-and-forget completion-handler overload
  (nullable handler, default nil); the call is typed to force the async variant.

## Crash backstop (sentinel)

The owner accepted that a crashed or interrupted run would skip the relaunch;
in this repo that is a realistic case (agent sessions run `swift test` under a
tool timeout that kills the process group). A `/bin/sh` sentinel is spawned with
`POSIX_SPAWN_SETSID` — its own session and process group, stdio on `/dev/null` —
so a Ctrl-C or a group kill of the test run does not reach it. It is armed with
the bundles before they are parked, polls the test process with `kill -0` once a
second, and when the process is gone runs `open -g <bundles>` (by-path matching:
no duplicate if a copy came back meanwhile). On the normal path the suite
relaunches in-process and then kills the sentinel; if that relaunch fails, the
failure is recorded and the sentinel stays armed as a second attempt at exit.

Verified on decoys with the real `TilerCopies` code: SIGKILL of the test process,
and a kill of its whole process group with a same-id copy still alive — the parked
copy came back exactly once both times.

## Live-session guard (skip, never park)

The suite is disabled when another copy holds any IOPM power assertion
(`IOPMCopyAssertionsByProcess`) or `pmset -g` reports `SleepDisabled 1`:

- Every Prevent Sleep session holds an assertion (idle/display/system; the
  lid-closed leg holds `PreventSystemSleep`). Matching *any* assertion instead of
  the "Tiler Keep Awake" names survives a rename; a stray extra assertion only
  costs a skipped run, the safe direction.
- `SleepDisabled 1` means a lid-closed session is armed or a leftover flag
  exists; the instance under test would raise its "Sleep is still disabled"
  alert at launch and block the E2E.

## Not changed

`Scripts/install.sh` still kills every copy — it replaces the installed app on
purpose. `Scripts/run-acceptance.sh` and `Scripts/record-golden.sh` match the
relative `build/Tiler.app/...` path, which never matches `~/Applications`; their
instances still share the owner's settings domain (out of scope here).
