# Change: add-onboarding-guide

## Why

Tiler works, but is mute about itself: the fixed hotkeys and gestures are not shown
anywhere in the app, a new user gets no explanation of what it does, and the
permission flow (bare Settings window) doesn't explain what's happening or what to
do. Owner request 2026-07-04: "оформим приложение красиво" — description, visible
hotkey/gesture reference, calibration path when gestures underperform, and a clear
startup permission experience.

## What Changes

- **Guide window** ("Welcome to Tiler"), reachable from the menu at any time:
  - one-line description of the app;
  - live permission card — green when granted; when missing: red, explains the
    consequence, one-click "Open Accessibility Settings", auto-clears when granted;
  - full cheat sheet: all hotkeys (keycap styling) and all gestures with small
    looping direction animations (reusing the calibration demo), incl. Cmd variants
    and the double-press ↑ semantics;
  - "Gestures not working?" section: conflict diagnostics summary inline + Calibrate
    button + link to Settings.
- **Startup flow v2**: first launch ever → Guide; any launch without Accessibility →
  Guide (replacing the bare Settings window as the landing).
- **Menu**: About / Shortcuts & Help / Settings… / Quit.

## Capabilities affected

| Capability | Delta |
|---|---|
| `app-shell` | MODIFIED — menu gains Shortcuts & Help; startup flow lands on the Guide; Guide window requirements ADDED |

## Non-goals

- Editable shortcuts (bindings stay fixed).
- Multi-page onboarding wizards, analytics, localization.

## Impact

- New SwiftUI GuideWindow; `SettingsStore.hasSeenGuide` persisted flag;
  AppDelegate menu/startup wiring. No recognizer/window-action changes.
