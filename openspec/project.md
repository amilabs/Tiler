# Tiler — Project Context

macOS menu-bar utility that moves/resizes the active window via fixed hotkeys and precise
3-finger trackpad gestures. Works through the Accessibility (AX) permission; must stay alive
and recover gracefully when the permission is missing.

## Tech stack

- Swift 6.3, AppKit, SwiftPM executable package (no .xcodeproj) — build and test fully from CLI.
- App bundle assembled by `Scripts/make-app.sh` (Info.plist with `LSUIElement`, codesign);
  installed to `~/Applications` by `Scripts/install.sh` (TCC-stable location).
- Codesign identity: **"Apple Development: alexnsk@gmail.com (PHYV972T38)"**, bundle id
  **pro.amilabs.tilerx** — both are TCC-load-bearing, change neither (self-signed certs
  don't enroll in Accessibility on macOS 26; the original `pro.amilabs.tiler` TCC record
  is wedged on the owner's machine). Full recipe: README "TCC enrollment on macOS 26".
- OS policy (owner rule, 2026-07-16): **target & tested OS is macOS 26** (dev
  machine 26.5.1, Xcode 26.6) — other versions are NOT tested (for now), but launch
  on them must never be blocked. Hence since v0.3.2: launch floor
  `LSMinimumSystemVersion`/platforms **15.0**, universal (arm64 + x86_64) binary.
  Owner verbatim: "на других мы не тестим (пока), но это не значит что надо
  запрещать запуск на них."
- Private framework `MultitouchSupport.framework` is linked for raw trackpad contact frames.
  App Sandbox stays disabled (required for both MultitouchSupport and AX control).
- No external dependencies without explicit owner approval.

## Environment facts

- GitHub remote: `git@github.com:amilabs/Tiler.git`; `gh` CLI authenticated (alexnskcody,
  keyring) since 2026-07-05 — GitHub API/releases available. Releases: tag `vX.Y.Z` +
  `gh release create` with the zip from `ditto -c -k --keepParent build/Tiler.app`.
  Every release ALSO installs locally right away (`Scripts/install.sh` + relaunch) —
  owner standing order 2026-07-17 ("всегда обновляй локально"); no need to ask, but
  report if a live Prevent Sleep session had to be killed, and remind about the
  one-time Accessibility re-confirm after re-signing.
- Node.js is NOT installed and must not be installed. The OpenSpec structure in this repo is
  maintained **manually by convention** (no `openspec` CLI). Keep it valid by hand.
- License: Apache-2.0.

## Workflow rules (owner-mandated)

1. **Everything is protocoled in OpenSpec.** Every task and assignment lives in
   `openspec/changes/<change-id>/tasks.md`; update checkboxes and specs **on any change**,
   not after the fact. New scope → new change folder (kebab-case id) with proposal/design/tasks/spec deltas.
2. **Minimize owner involvement, never at the expense of quality.** Prefer self-testing
   (unit tests, replayed traces, AX read-back, CPU sampling). Consolidate unavoidable
   questions/permission requests into single batched asks. Owner gates are marked
   `[USER GATE]` in tasks.md.
3. False positives of gestures are **blockers** — see `specs` deltas in the active change.
   Numeric thresholds in the owner's brief are **empirical guidelines, not contracts**
   (owner statement, 2026-07-04): retune them from golden-trace evidence whenever
   practice disagrees, keep false-positive zero as the invariant, and document every
   deviation in the spec with data and date (see the horizontalDominance retune).
4. TDD for all recognizer/window logic; verification evidence before claiming done.
5. Completed changes move to `openspec/changes/archive/YYYY-MM-DD-<change-id>/` and their
   requirement deltas are merged into `openspec/specs/`.

## Build / test (will be kept current)

```sh
swift build                 # debug build
swift test                  # unit tests (gesture FSM etc.)
Scripts/make-app.sh         # assemble + codesign Tiler.app (release)
Scripts/run-acceptance.sh   # integration/acceptance suites (needs AX granted to host)
```

## Active changes

- None. Start new work as a fresh change folder (kebab-case) with
  proposal/design/tasks/spec deltas.

Archived: `2026-07-17-add-conflict-indicators` (v0.3.3: colored menu alerts —
red = permission, orange = gesture conflicts — plus a "Gestures ⚠︎" tab mark; all
conflict marks gated on gesturesEnabled, mock-gated with the owner),
`2026-07-16-lower-macos-floor` (v0.3.2: launch floor macOS 26 → 15,
universal arm64+x86_64 binary; target/tested OS stays 26 — untested ≠ blocked;
zero availability changes needed; field result 2026-07-17: full gesture matrix +
calibration + conflict diagnostics confirmed working on the 15.1.1 laptop),
`2026-07-16-fix-touch-stream-resilience` (v0.3.1: gesture stream
recovery — the MT stream can die with no system sleep (field bug, second laptop);
guardian rebuilds on wake/display change/device-ID drift/silence self-heal with
full diagnostics; field verification on the second laptop pending),
`2026-07-10-add-power-control` (v0.3.0: Prevent Sleep sessions —
indefinite/timed/until-a-set-time, battery floor, lid-closed keep-awake via a
foreground admin watchdog, Deep Sleep battery hibernate profile, opt-in power/
gesture debug log; gate 4.2 passed over days of owner hands-on runs),
`2026-07-04-add-tiler-mvp` (MVP), `2026-07-04-add-shell-and-calibration`
(v0.2: icon/About/Settings, startup flow, per-user calibration, dominance retunes),
`2026-07-04-add-onboarding-guide` (Guide window, cheat sheet, conflict alerting,
startup flow v2), `2026-07-05-unify-about-guide` (single-entry unified window,
marketing About, calibration progress, cross-display fix, tabbed Settings),
`2026-07-05-stabilize-menu` (final menu, CPU-budget fix + honest measurement,
no-scroll layout, release 0.2.0 tooling), `2026-07-05-add-thirds-lock-help`
(⇧-thirds gestures, ⌃A lock screen, Help label), `2026-07-05-add-shift-up-third`
(⇧+up → center-third), `2026-07-05-split-hotkey-groups` (independent window/utility
hotkey toggles, window group OFF by default; calibration step sound),
`2026-07-06-add-snap-glyphs` (cheat-sheet placement diagrams). Specs in
`openspec/specs/` are current truth. Released: v0.3.3 (GitHub release with zip, universal, macOS 15+).
