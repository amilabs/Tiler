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
Scripts/make-app.sh           # signed build/Tiler.app (Apple Development identity)
Scripts/install.sh            # install to ~/Applications for a stable Accessibility grant
```

Requires macOS 26+. **Developed and verified exclusively on macOS 26.5 (Apple
Silicon)** — every acceptance claim in this repo refers to that configuration.
Older macOS: assessed as low-risk to port (public APIs are macOS 13-era; the
private multitouch struct layout has been stable for years), but explicitly NOT
tested — lowering the deployment target is a small build change gated on a real
acceptance run on such a machine (gestures can't be verified in a VM: no
multitouch devices there). The app is unsandboxed (private MultitouchSupport
framework + Accessibility API) and is not App Store distributable.

The menu bar item (pinch icon; ⚠︎ suffix when unpermitted) opens About and
**Settings**: gestures/hotkeys toggles, permission status with a fix path, launch
at login, conflict diagnostics, and **gesture calibration** — a guided dialog that
measures your own swipes (animated demo, live per-attempt feedback) and derives
personal thresholds, clamped to ranges that provably cannot re-enable false
positives. Reset to defaults any time.

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

### TCC enrollment on macOS 26 — the hard-won recipe

Symptom we fought: the Accessibility prompt appears, but the app's row **silently
never persists** in System Settings (not via the prompt, not via "+", not via drag).
Root causes found on 2026-07-04, in order of discovery:

1. **Self-signed identities don't enroll.** A locally created certificate — even
   imported as a trusted Code Signing root into the *System* keychain — shows the
   prompt but tccd refuses to create the row. An Apple-issued **Apple Development**
   certificate is required (free Apple ID is enough; Xcode → Settings → Accounts →
   Manage Certificates → "+").
2. **Expired WWDR intermediate breaks the identity.** If `security find-identity`
   shows the Apple Development cert as `CSSMERR_TP_NOT_TRUSTED`, the Apple WWDR G3
   intermediate is missing/expired locally. Fix: import
   https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer into the login
   keychain.
3. **A TCC client record can wedge.** After many grant/reset cycles, the record for
   the original bundle id (`pro.amilabs.tiler`) got stuck: prompts shown, row never
   created, reboot didn't help, `tccutil reset` reported success but changed nothing.
   A **fresh bundle id** enrolled instantly — hence the current id
   `pro.amilabs.tilerx`. Don't "clean it up" back to the old id: the grant follows
   (bundle id + signing team), and the old id is dead on this machine.
4. **The list row may vanish while the grant persists.** System Settings sometimes
   stops SHOWING the Tiler row even though the TCC grant is alive (windows still
   move; `Tiler --ax-report <file>` prints `trusted=true`). Cosmetic Settings-UI
   flakiness on this machine — verify functionally, don't chase the row.

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

Spec-driven: see [openspec/project.md](openspec/project.md), current requirement
specs in [openspec/specs/](openspec/specs/), and archived changes with full design
history in [openspec/changes/archive/](openspec/changes/archive/). Gesture logic is a
pure state machine (`TilerCore`) developed strictly test-first; system integration
lives in `TilerSystem`.

- `Scripts/run-acceptance.sh` — self-service acceptance: launch health, idle CPU < 1%,
  kill -9 resilience
- `Scripts/record-golden.sh` — record real-trackpad traces into replayable fixtures
- `Scripts/acceptance-checklist.sh` — final manual checklist

License: Apache-2.0.
