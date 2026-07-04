# Tiler — Project Context

macOS menu-bar utility that moves/resizes the active window via fixed hotkeys and precise
3-finger trackpad gestures. Works through the Accessibility (AX) permission; must stay alive
and recover gracefully when the permission is missing.

## Tech stack

- Swift 6.3, AppKit, SwiftPM executable package (no .xcodeproj) — build and test fully from CLI.
- App bundle assembled by `Scripts/make-app.sh` (Info.plist with `LSUIElement`, codesign).
- Codesign identity: **"WindowGestures Local Dev"** (already in the login keychain).
  Always sign with it so TCC grants survive rebuilds. Never ship ad-hoc signed builds.
- Deployment target: **macOS 26 only** (owner's machine: macOS 26.5.1, Xcode 26.6). Approved decision.
- Private framework `MultitouchSupport.framework` is linked for raw trackpad contact frames.
  App Sandbox stays disabled (required for both MultitouchSupport and AX control).
- No external dependencies without explicit owner approval.

## Environment facts

- GitHub remote: `git@github.com:amilabs/Tiler.git` (SSH only; `gh` CLI is NOT authenticated —
  do not rely on GitHub API).
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

- `add-tiler-mvp` — initial MVP (hotkeys, gestures, window actions, permission lifecycle, menu bar).
