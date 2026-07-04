# settings — delta for add-shell-and-calibration

## ADDED Requirements

#### Requirement: Settings window

Tiler SHALL provide a Settings window (opened from the menu) with: a Gestures
enable/disable toggle, a Hotkeys enable/disable toggle, the Accessibility permission
status, and a Calibration entry point. All toggles SHALL persist across relaunches
and apply immediately (no restart).

##### Scenario: Disabling hotkeys
- WHEN the user turns the Hotkeys toggle off
- THEN pressing any Tiler hotkey does nothing until re-enabled, and the setting
  survives an app relaunch

##### Scenario: Disabling gestures
- WHEN the user turns the Gestures toggle off
- THEN 3-finger swipes trigger no actions until re-enabled, and the setting survives
  an app relaunch

#### Requirement: Permission status with problem highlight

The Settings window SHALL show whether Accessibility is granted. When missing, the
problem SHALL be visually highlighted with a short explanation and a button opening
the system Accessibility pane.

##### Scenario: Missing permission highlighted
- WHEN Settings opens while Accessibility is not granted
- THEN the permission row is visibly marked as a problem and offers a one-click path
  to the system pane; once granted, the highlight clears without restart
