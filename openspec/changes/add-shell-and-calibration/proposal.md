# Change: add-shell-and-calibration

## Why

The MVP is accepted and daily-usable, with two gaps. First, the app has no identity or
controls: no icon, no About, no Settings — the menu is a grab-bag and permission
problems are only visible as a glyph. Second, gesture thresholds are global constants,
while hands differ: the owner's right swipe still under-detects even after the
golden-trace retune (accepted MVP carry-over). The durable fix is per-user calibration
with live feedback, not endless default-tweaking.

## What Changes

- **App identity:** app icon (owner picks 1 of 3 proposed concepts), About window
  (version, build time, GitHub link), menu reduced to About / Settings / Quit with an
  alert-state icon when Accessibility is missing.
- **Settings window:** gestures on/off, hotkeys on/off, Accessibility status with
  problem highlight + one-click fix path, calibration entry point. Toggles persist.
- **Startup flow:** on launch without Accessibility — notify and open the dialog/pane
  (beyond the current one-shot system prompt).
- **Gesture calibration (per user):** guided dialog — a mini animation demonstrates
  each gesture, the user performs it several times, live success/accuracy feedback
  animates progress; result = personal `Tunables` overrides persisted and applied
  without restart. Includes a data-driven default retune for the right swipe from a
  fresh rights-only trace.

## Capabilities affected

| Capability | Delta |
|---|---|
| `app-shell` | MODIFIED — icon, About, menu restructure, startup permission flow |
| `settings` | ADDED — settings window, persisted toggles, permission status |
| `calibration` | ADDED — guided calibration flow, per-user tunables |
| `gestures` | MODIFIED — recognizer accepts persisted per-user tunables |
| `hotkeys` | MODIFIED — enable/disable toggle |

## Non-goals

- Custom key remapping or gesture-to-action mapping UI.
- Multi-profile calibration, cloud sync, localization (English UI for now).
- Notarization/distribution work.

## Impact

- New UI layer (SwiftUI windows hosted from the menu-bar app), icon assets,
  build-time stamping in `make-app.sh`.
- `TilerCore` gains a pure `CalibrationSession` (TDD) that consumes the same
  `TouchFrame` stream and recognizer verdicts to compute per-gesture stats and
  suggested tunables.
- Persisted tunables introduce a compatibility surface: calibration output must be
  clamped to safe ranges so a bad calibration can never re-enable false positives
  (blocker invariant stays absolute).
