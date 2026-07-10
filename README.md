<p align="center">
  <img src="docs/screenshots/guide.png" width="740" alt="Tiler — hotkeys and trackpad gesture reference">
</p>

# Tiler

A macOS menu-bar utility that places the active window with hotkeys and
three-finger trackpad swipes: halves, full screen, a centered third — on any of
your displays.

- Recognizes a swipe only when exactly three fingers move together in one
  direction, so ordinary scrolling and resting palms don't affect your windows.
- Swipe angles can be calibrated to your hand in about a minute.
- Light on resources: under 1% CPU when your fingers are off the trackpad.
- **Prevent Sleep**: keep the Mac awake on demand — indefinitely, for a set
  duration, until a chosen time, or with the lid closed — plus an optional
  battery-side **Deep Sleep** (hibernate) profile.

## Shortcuts and gestures

| Input | Action |
|---|---|
| ⌃⇧← / ⌃⇧→ | left / right half of the current screen |
| ⌃⇧↑ | maximize |
| ⌃⇧↑ ↑ (double press) | full height, centered, ⅓ width |
| ⌃⇧↓ | restore the window's previous frame |
| ⌘⌃⇧← / ⌘⌃⇧→ | halves on the next display |
| ⌃A | lock the screen |
| 3-finger swipe ← / → / ↑ | left half / right half / maximize |
| ⇧ + 3-finger swipe ← / → / ↑ | left third / right third / centered third |
| ⌘ + 3-finger swipe ← / → | halves on the next display (⇧ combines: thirds) |

Swipe-down, two- and four-finger movements do nothing. The full reference lives
in the app: menu bar → **Tiler**.

## Prevent Sleep

The menu-bar **Prevent Sleep** section keeps the Mac awake on command —
indefinitely, for a fixed duration (10 min … 24 h), or until a specific time.
The menu-bar icon turns red with a coffee-cup badge while a session runs.

- **Keep display awake** (Settings → Power) also holds the screen on; off by
  default, so only the system stays awake.
- **Battery floor** (default 20%) auto-stops a session on battery once the
  charge drops to the floor, with a notification and no surprise restart.
- **Prevent sleep with the lid closed** runs the Mac folded; it needs an
  administrator password and gets hot — never leave it in a bag.
- **Deep Sleep on lid close** (Settings → Power) switches the battery-side sleep
  profile to full hibernation for near-zero drain; wake then takes ~10–20 s.

## Install

1. Download `Tiler-x.y.z.zip` from [Releases](https://github.com/amilabs/Tiler/releases).
2. Unzip and move `Tiler.app` to `~/Applications`.
3. Open it and grant the **Accessibility** permission when asked — that's the one
   thing Tiler needs to move windows.

Window-tiling hotkeys (⌃⇧ arrows) are **off by default** — turn them on in
**Settings → General** if you want them alongside the gestures. The ⌃A lock-screen
hotkey is on by default.

Requires macOS 26 or later (verified on macOS 26.5, Apple Silicon).

## If gestures don't work well

Open **Tiler → Settings → Gestures → Calibrate** — a guided one-minute dialog
adapts recognition to how you actually swipe. If system three-finger gestures
(Mission Control, three-finger drag) are enabled, Tiler will point at the exact
setting to change.

---

License: Apache-2.0
