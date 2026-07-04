# app-shell — delta for unify-about-guide

## MODIFIED Requirements

#### Requirement: Menu-bar-only application (modified)

The menu SHALL contain exactly TWO items: **Tiler…** (the single entry point,
opening the unified window) and **Quit**. Settings SHALL be reachable from within
the unified window (prominent button in the header, plus the troubleshooting link).

#### Requirement: About & Guide window (replaces separate About window and Guide window)

One window SHALL serve both roles, containing: an animated hero (cycling gesture
demo) with the app name and a one-line tagline; a short value section grounded in
the original brief (reliability/no false positives, per-hand calibration,
lightweight resilience); the live permission card; the complete hotkey and gesture
reference (keycaps + looping direction animations, Cmd variants, double-press ↑,
restore); the troubleshooting section (inline conflicts + Calibrate); and a footer
with version, build time in the user's local timezone, and the GitHub link.

##### Scenario: One window, both entry points
- WHEN the user opens About Tiler from the menu, or the startup flow triggers
- THEN the same unified window opens

##### Scenario: Story and reference in one place
- WHEN the unified window is open
- THEN the user can read what the app is for AND see every binding/gesture without
  opening anything else

#### Requirement: Fits small screens

Auxiliary windows SHALL never exceed the screen's visible height: the unified
window's content scrolls vertically when it does not fit, and window heights are
clamped to the visible frame.

##### Scenario: Small display
- WHEN the unified window opens on a display whose visible height is smaller than
  the full content
- THEN the window is clamped to the screen and the content is reachable by scrolling
