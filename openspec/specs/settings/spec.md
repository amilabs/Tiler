# settings — current spec (merged from add-shell-and-calibration, 2026-07-04)

## Requirements

#### Requirement: Settings window

Tiler SHALL provide a Settings window (opened from the unified window) with a Gestures
enable/disable toggle, two independent hotkey toggles — "Window tiling hotkeys" (default
off) and "Lock screen hotkey ⌃A" (default on) — the Accessibility permission status, and
a Calibration entry point. All toggles SHALL persist across relaunches and apply
immediately (no restart). The window SHALL be organized so its content fits without
vertical scrolling on ordinary displays (tabbed: General / Gestures).

##### Scenario: Disabling the window-tiling hotkeys
- WHEN the user turns the Window tiling hotkeys toggle off
- THEN pressing any ⌃⇧ arrow does nothing (they reach other apps) until re-enabled,
  while ⌃A still locks the screen; the setting survives an app relaunch

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

#### Requirement: Power tab

The Settings window SHALL gain a Power tab with: "Keep display awake" (default off),
the battery floor picker (Off / 30% / 20% / 10%, default 20%), the "Deep Sleep on
lid close" toggle with a short explanation (full hibernate on battery sleep, wake
takes ~10–20 s, admin authorization on toggle), and a Diagnostics section with an
opt-in "Debug logging" toggle (default off) plus a "Reveal Log" button. All controls
persist across relaunches and apply without restart, matching existing settings
behavior. The tab SHALL fit without vertical scrolling (existing no-scroll rule).

##### Scenario: Floor picker persists
- WHEN the user selects a 10% floor and relaunches Tiler
- THEN the picker still shows 10% and the floor is enforced for the next session

##### Scenario: Deep Sleep toggle reflects reality
- WHEN the pmset profile was changed outside Tiler
- THEN the toggle state after relaunch matches `pmset -g custom`, not the stale
  stored preference

#### Requirement: Gestures tab conflict mark

While system gesture conflicts are detected AND gestures are enabled, the Gestures
tab item SHALL carry a "⚠︎" title suffix ("Gestures ⚠︎") so the conflict section is
discoverable without opening the tab. macOS tab items cannot be colored — the suffix
renders in the label color; the orange accent lives in the conflict rows inside the
tab and on the menu's Settings item (app-shell spec). With gestures disabled or no
conflicts the tab title stays plain "Gestures".

##### Scenario: Mark appears and clears live
- WHEN a system 3-finger gesture setting is enabled while the Settings window shows
  no conflicts, and the window refreshes (reopen / conflict refresh)
- THEN the tab reads "Gestures ⚠︎", and returns to "Gestures" once the system
  setting is moved to four fingers or Tiler's gestures are switched off
