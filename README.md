# Tiler

macOS menu-bar utility: move and resize the active window with fixed hotkeys and precise
3-finger trackpad gestures. Reliability-first: strict exact-3-finger detection, zero
tolerance for false positives during normal scrolling.

## Actions

| Input | Action |
|---|---|
| Ctrl+Shift+← / → | left / right half of the current screen |
| Ctrl+Shift+↑ | maximize (after a ~300 ms double-press window) |
| Ctrl+Shift+↑ ×2 | full height, centered, 1/3 width |
| Ctrl+Shift+↓ | restore the window's pre-Tiler frame |
| Cmd+Ctrl+Shift+← / → | halves on the next display |
| 3-finger swipe ← / → / ↑ | left half / right half / maximize |
| Cmd + 3-finger swipe ← / → | halves on the next display |

3-finger swipe down is deliberately not implemented; 2- and 4-finger movements never
trigger anything.

## Build & run

```sh
swift build && swift test     # library + unit tests
Scripts/make-app.sh           # signed build/Tiler.app (identity: WindowGestures Local Dev)
Scripts/install.sh            # install to ~/Applications for a stable Accessibility grant
```

Requires macOS 26+. The app is unsandboxed (needs the private MultitouchSupport
framework and the Accessibility API) and is not App Store distributable.

**Install to ~/Applications, not build/.** Grant Accessibility to the copy in
`~/Applications` (via `Scripts/install.sh`). Two reasons:
- `make-app.sh` deletes and recreates `build/Tiler.app` on every build, which drops
  the TCC grant on the bundle you granted.
- macOS is reluctant to persist Accessibility grants for apps under a world-writable
  path (this repo lives under `/Users/Shared`, whose root is `drwxrwxrwt`).

**Launch context matters for the grant.** Accessibility is attributed to the
"responsible process". Launch Tiler on its own (Finder double-click, `open`, or at
login) so it is its own responsible process. If you launch its binary as a child of a
terminal that already has Accessibility, Tiler *inherits* that grant and will appear to
work without its own entry — misleading, since a normal launch won't.

## Permissions

Tiler needs **Accessibility** (System Settings → Privacy & Security → Accessibility).
Without it, Tiler stays alive, shows ▦⚠︎ in the menu bar, and moves no windows; once
granted it recovers within seconds, no relaunch needed. Hotkey registration and gesture
recognition never require the permission and never install event taps — a hung or
killed Tiler cannot affect system input.

## Conflicting system gestures

System three-finger gestures consume swipes before Tiler sees them. Check with
`Scripts/diagnose.sh` or the in-app **Diagnostics** menu:

- Accessibility → Pointer Control → Trackpad Options → *three-finger drag* — off
- Trackpad → More Gestures → *Mission Control / App Exposé / Swipe between full-screen
  applications* — set to four fingers or off

## Development

Spec-driven: see [openspec/project.md](openspec/project.md) and the active change
[openspec/changes/add-tiler-mvp/](openspec/changes/add-tiler-mvp/) (proposal, design,
requirement specs, task plan). Gesture logic is a pure state machine (`TilerCore`)
developed strictly test-first; system integration lives in `TilerSystem`.

- `Scripts/run-acceptance.sh` — self-service acceptance: launch health, idle CPU < 1%,
  kill -9 resilience
- `Scripts/record-golden.sh` — record real-trackpad traces into replayable fixtures
- `Scripts/acceptance-checklist.sh` — final manual checklist

License: Apache-2.0.
