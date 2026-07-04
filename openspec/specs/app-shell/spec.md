# app-shell — current spec (merged from add-tiler-mvp, 2026-07-04)

## Requirements

#### Requirement: Menu-bar-only application

Tiler SHALL run as an `LSUIElement` app with an `NSStatusItem` (no Dock icon, no main
window). The menu SHALL provide: permission status (with a shortcut to the System
Settings Accessibility pane), gestures enable/disable toggle, Diagnostics, Launch at
Login (SMAppService), version, Quit.

##### Scenario: Warning state visible
- WHEN AX permission is missing
- THEN the status item shows a distinct warning appearance and the menu explains how to fix it

#### Requirement: Conflict diagnostics

Diagnostics SHALL report (read-only) system settings that compete with Tiler's gestures:
Three Finger Drag (Accessibility), three-finger Mission Control / App Exposé / Spaces
swipes (Trackpad › More Gestures), reading the relevant `defaults` domains. Tiler SHALL
NOT modify system settings. The README SHALL document these conflicts and that gesture
acceptance is performed with system three-finger gestures disabled.

##### Scenario: Three Finger Drag enabled
- WHEN TrackpadThreeFingerDrag is enabled in system settings
- THEN Diagnostics lists it as a conflict with guidance to disable it for gesture use

#### Requirement: Idle CPU budget

With the trackpad untouched and permission granted, Tiler's process CPU SHALL stay below
1% (no polling timers in steady state; multitouch callback is push-based; hotkeys are
event-driven).

##### Scenario: 60-second idle sample
- WHEN Tiler idles for 60 s with no trackpad contact and permission granted
- THEN sampled CPU (`ps -o %cpu`) stays < 1%

#### Requirement: Crash and kill safety

Tiler SHALL install no mechanism that could persist input interference beyond its
process lifetime. Force-killing Tiler at any moment SHALL leave keyboard, trackpad, and
system gestures fully functional.
