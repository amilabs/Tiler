# app-shell — delta for add-onboarding-guide

## MODIFIED Requirements

#### Requirement: Menu-bar-only application (modified)

The menu SHALL contain exactly: **About Tiler**, **Shortcuts & Help**, **Settings…**,
**Quit**. (Shortcuts & Help opens the Guide window.)

#### Requirement: Startup permission flow (modified)

On the very first launch, and on any launch without the Accessibility permission,
Tiler SHALL open the Guide window (instead of the bare Settings window). The app
continues running normally otherwise; subsequent permitted launches open nothing.

##### Scenario: First launch ever
- WHEN Tiler launches for the first time on a machine
- THEN the Guide window opens, introducing the app, its shortcuts, and permissions

##### Scenario: Launch without permission
- WHEN Tiler starts while Accessibility is not granted
- THEN the Guide opens with the permission card highlighted and a one-click path to
  the system pane

## ADDED Requirements

#### Requirement: Guide window

The Guide ("Welcome to Tiler") SHALL show: a one-line description of the app; a live
permission card (granted = calm confirmation; missing = highlighted problem with an
"Open Accessibility Settings" button, clearing automatically once granted, no
relaunch); a complete reference of ALL hotkeys (keycap styling) and ALL gestures
(with looping direction animations), including Cmd variants, the 300 ms double-press
↑ semantics and restore; and a "Gestures not working?" section with inline conflict
diagnostics and a Calibrate button.

##### Scenario: Cheat sheet completeness
- WHEN the Guide is open
- THEN every binding from the hotkeys spec and every gesture from the gestures spec
  is visible with its action

##### Scenario: Permission granted while Guide is open
- WHEN the user grants Accessibility in System Settings while the Guide shows the
  missing-permission card
- THEN the card switches to the granted state within a few seconds without relaunch

##### Scenario: Troubleshooting path
- WHEN gestures underperform and the user opens the Guide
- THEN conflicting system gestures (if any) are listed inline and one click starts
  calibration

#### Requirement: Conflict alerting (modified diagnostics)

Beyond read-only reporting, Tiler SHALL actively alert on conflicting system
gestures: the status item shows its alert appearance with an explanatory tooltip;
the check re-runs at launch and on every menu open; a launch with conflicts present
opens the Guide.

##### Scenario: Conflict appears while Tiler runs
- WHEN a conflicting system trackpad setting is enabled while Tiler is running
- THEN the next menu open shows the alert glyph, and the Guide lists the conflict
  with guidance

##### Scenario: About window content
- WHEN About opens
- THEN it shows a multi-sentence description of what Tiler does, the version, the
  build time in the user's LOCAL timezone, and the GitHub link
