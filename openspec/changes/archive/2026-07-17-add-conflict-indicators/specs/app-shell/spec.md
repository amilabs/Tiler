# app-shell — delta for add-conflict-indicators

## MODIFIED Requirements

#### Requirement: Conflict diagnostics

Diagnostics SHALL report (read-only) system settings that compete with Tiler's gestures:
Three Finger Drag (Accessibility), three-finger Mission Control / App Exposé / Spaces
swipes (Trackpad › More Gestures), reading the relevant `defaults` domains. Tiler SHALL
NOT modify system settings. The README SHALL document these conflicts and that gesture
acceptance is performed with system three-finger gestures disabled.

Alert surfaces (owner gate 2026-07-17): the menu's Settings item SHALL carry a colored
⚠ mark — red for the missing Accessibility permission (critical; also the pre-existing
behavior upgraded from a monochrome glyph), orange for gesture conflicts; the
permission mark wins when both apply. The menu-bar status glyph keeps showing ⚠ for
either cause. EVERY conflict-driven mark (menu item, status glyph, Settings tab —
see the settings spec) SHALL appear only while gestures are enabled: with gestures
off a conflict is not critical and MUST NOT distract. Marks refresh live on settings
changes and on menu open (existing refresh points).

##### Scenario: Three Finger Drag enabled
- WHEN TrackpadThreeFingerDrag is enabled in system settings
- THEN Diagnostics lists it as a conflict with guidance to disable it for gesture use

##### Scenario: Conflicts with gestures disabled
- WHEN system gesture conflicts exist but the user has turned Tiler's gestures off
- THEN no conflict mark appears in the menu bar, the menu, or the Settings tab

##### Scenario: Both alerts at once
- WHEN the Accessibility permission is missing AND conflicts exist
- THEN the Settings item shows the red permission mark
