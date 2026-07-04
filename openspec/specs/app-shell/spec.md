# app-shell — current spec (merged from add-tiler-mvp, 2026-07-04)

## Requirements

#### Requirement: Menu-bar-only application

Tiler SHALL run as an `LSUIElement` app with an `NSStatusItem` (no Dock icon, no main
window). The menu SHALL contain exactly: About Tiler, Shortcuts & Help, Settings…,
Quit. Permission status/fix path, toggles, Launch at Login, and Diagnostics live in
Settings (settings spec); Shortcuts & Help opens the Guide. The status item SHALL show
a distinct alert appearance (with explanatory tooltip) when Accessibility is missing
OR conflicting system gestures are detected; the conflict check re-runs at launch and
on every menu open.

##### Scenario: Warning state visible
- WHEN AX permission is missing
- THEN the status item shows a distinct alert appearance until the permission is granted

#### Requirement: App icon

Tiler.app SHALL ship an app icon (owner-picked hand.pinch glyph on the violet tile,
generated at build) and a matching template menu-bar icon.

#### Requirement: About window

The About window SHALL show the app name/icon, a multi-sentence description of what
Tiler does, the version, the build timestamp (injected at build time, displayed in
the user's local timezone), and a clickable link to https://github.com/amilabs/Tiler.

##### Scenario: Build time reflects the actual build
- WHEN the app is rebuilt and About is opened
- THEN the displayed build timestamp matches the new build, not a stale constant

#### Requirement: Startup flow

On the very first launch, on any launch without Accessibility, and on any launch with
conflicting system gestures detected, Tiler SHALL open the Guide window (live
permission card, full hotkey/gesture reference, troubleshooting with inline conflicts
and a Calibrate button), continuing to run normally otherwise. Granting the permission
while the Guide is open SHALL flip its permission card without relaunch.

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
