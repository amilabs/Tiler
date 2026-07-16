# app-shell — current spec (last merged: unify-about-guide, 2026-07-05)

## Requirements

#### Requirement: Menu-bar-only application

Tiler SHALL run as an `LSUIElement` app with an `NSStatusItem` (no Dock icon, no main
window). The menu SHALL contain exactly: **Help** (opens the unified About & Guide
window), **Settings** (⌘,; with a visible ⚠︎ marker while Accessibility is missing),
and **Quit** — labels without ellipses. Settings is also reachable from the unified
window's header button. The
status item SHALL show a distinct alert appearance (with explanatory tooltip) when
Accessibility is missing OR conflicting system gestures are detected; the conflict
check re-runs at launch and on every menu open.

##### Scenario: Warning state visible
- WHEN AX permission is missing
- THEN the status item shows a distinct alert appearance until the permission is granted

#### Requirement: App icon

Tiler.app SHALL ship an app icon (owner-picked hand.pinch glyph on the violet tile,
generated at build) and a matching template menu-bar icon.

#### Requirement: Unified About & Guide window

One window SHALL serve as About, guide, and entry point, containing: an animated hero
(cycling gesture demo) with the app name and a one-line tagline; a short value section
grounded in the original brief (reliability/no false positives, per-hand calibration,
lightweight resilience); the live permission card; the complete hotkey and gesture
reference (keycaps + looping direction animations, Cmd variants, double-press ↑,
restore); a troubleshooting section (inline conflicts + Calibrate); a prominent
Settings entry; and a footer with version, build timestamp (injected at build,
displayed in the user's LOCAL timezone), the honest verified-configuration note
("verified on macOS 26.5 only" until another configuration passes acceptance),
and the GitHub link.

##### Scenario: Build time reflects the actual build
- WHEN the app is rebuilt and the unified window is opened
- THEN the displayed build timestamp matches the new build, not a stale constant

#### Requirement: Cheat-sheet placement glyphs

The cheat sheet SHALL present Trackpad gestures before Hotkeys (gestures are the
primary interaction). Each row SHALL read left-to-right: input (keycaps / gesture
demo), action text, then a static placement glyph in the trailing column: a screen
outline with the target region drawn as a small window (title bar + dots); tiling
positions carry no arrow (the filled window shows placement); restore is a bold
counter-clockwise revert arrow encircling a centered window; next-display shows the
target screen in front with the source tucked behind as a dim dashed outline; ⌃A is
a padlock. Glyphs are non-animated (no idle CPU; render in release screenshots).

##### Scenario: Placement is visible at a glance
- WHEN the unified window is open
- THEN each action shows a diagram of where the window will land, not text alone

##### Scenario: Story and reference in one place
- WHEN the unified window is open
- THEN the user can read what the app is for AND see every binding/gesture without
  opening anything else

#### Requirement: Fits without vertical scrolling

The unified window SHALL fit ordinary displays with NO vertical scrolling: a
two-column layout (story/troubleshooting left, full hotkey/gesture reference right;
header, permission card and footer spanning both) within ≈880×780 pt. Auxiliary
window heights remain clamped to the screen's visible frame as a safety net.

##### Scenario: Everything visible at once
- WHEN the unified window opens on a display with ≥800 pt of visible height
- THEN all sections are visible simultaneously without scrolling

#### Requirement: Startup flow

On the very first launch, on any launch without Accessibility, and on any launch with
conflicting system gestures detected, Tiler SHALL open the unified window (permission
card highlighted when relevant), continuing to run normally otherwise. Granting the
permission while the window is open SHALL flip its permission card without relaunch.

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

With the trackpad untouched, Tiler's process CPU SHALL stay below 1% in EVERY
no-finger state: freshly launched with no UI, with the unified window open (demo
animations are static poses; they animate only under the pointer or during an active
calibration; occluded windows pause everything), and after UI windows are closed
(closed windows are fully released — retained off-screen animations are the
regression this guards against). CPU SHALL be measured as true utilization
(cputime delta over a wall interval) — `ps %cpu` is a lifetime average on macOS and
lies in both directions.

##### Scenario: Idle after launch
- WHEN Tiler idles with no trackpad contact and no windows
- THEN true utilization stays < 1%

##### Scenario: Idle with the unified window open
- WHEN the unified window is open and focused but the trackpad is untouched
- THEN true utilization stays < 1%

##### Scenario: Idle after the UI was used
- WHEN the unified window was opened and then closed
- THEN true utilization returns below 1% (measured 2026-07-05: 0.13% / 0.50% /
  0.20% for the three states; pre-fix regression burned 15–21%)

#### Requirement: Crash and kill safety

Tiler SHALL install no mechanism that could persist input interference beyond its
process lifetime. Force-killing Tiler at any moment SHALL leave keyboard, trackpad, and
system gestures fully functional.

#### Requirement: Menu Power section

The status-item menu SHALL gain a Power section between the primary items and Quit:
a "Prevent Sleep" submenu (start indefinite, the seven fixed durations, a single
"Prevent sleep with lid closed…" ⚠ item, Stop) whose header line shows the active
state and remaining time. The lid-closed item SHALL open a focused help-styled dialog (a centered card, not a
plain alert) that picks the duration and carries the heat warning (a "no laptop in a
bag" image — a laptop in a bag crossed out by the red prohibitory sign), then starts a
clamshell session — one atomic, deliberate step,
with no duplicated duration list and no menu-closing checkbox (a checkbox could not be
set together with a duration in one pass; the owner hit exactly that at gate 4.2 and no
clamshell session ever started). The dialog SHALL pre-select the currently running
duration (else default to 2 h), and the submenu's duration list SHALL mark the running
timer whether the session is normal or lid-closed. The submenu SHALL also offer an
"Until a specific time…" item that opens a help-styled dialog with an end date/time
picker (session runs until then); the same end-time option SHALL be available inside
the lid-closed dialog's picker. While a session is active the main menu SHALL ALSO show a prominent
row at its very top (bold, with the red cup mark) stating the feature and the
remaining time / lid-closed state (owner request 2026-07-08); the row is hidden when
inactive and clicking it SHALL stop the session after a confirmation dialog (so an
accidental click can't silently re-enable sleep); the explicit submenu "Stop" acts
without a prompt. The submenu SHALL mark the running start choice (until-stopped or
the chosen duration) with a checkmark. Menu state SHALL
refresh when the menu opens (existing `menuWillOpen` path); for a timed session the top
row and header SHALL tick live (once per second) while the menu is open, but no ticking
is required while the menu is closed.

##### Scenario: Menu reflects the running session
- WHEN the menu opens 12 minutes into a 30-minute "For 30 minutes" session
- THEN the prominent top row and the submenu header both show roughly "18 min left"
  (updating each second while open), "For 30 minutes" carries a checkmark, and clicking
  the top row stops the session

#### Requirement: Status item session state

While a session is active the status item SHALL show the monochrome hand glyph badged
with a solid red disc + white cup silhouette at its bottom-right (approved mockup,
gate 2.1), coexisting with the ⚠ permission/conflict marker; the badge is re-rendered
only when the active state or the menu-bar appearance changes.

##### Scenario: Session indicator
- WHEN a session is active and permissions are fine
- THEN the status item shows the red-cup badge and no ⚠

#### Requirement: Gesture stream recovery

(Broadened from "Gesture recovery after system wake" by fix-touch-stream-resilience,
v0.3.1.) The MultitouchSupport contact stream can go stale without the app crashing —
its device refs die across a real system sleep (observed at gate 4.2 of
add-power-control) and can also die with no system sleep at all (observed in the
field 2026-07-15: stream dead after a display sleep / lock cycle afternoon, no
`didWake` ever fired again, gestures stayed dead until relaunch). Tiler SHALL
therefore rebuild the stream (stop + start → fresh device list; on failure, full
pipeline rebuild) on EVERY one of these triggers:

1. ~1.5 s after `NSWorkspace.didWakeNotification` (system wake);
2. after a debounced display reconfiguration
   (`didChangeScreenParametersNotification`) — dock/undock re-enumerates HID devices;
3. on device drift — the set of multitouch device IDs from a fresh enumeration
   differs from the IDs the stream attached to — checked shortly after screen unlock
   and by a periodic (~60 s) watchdog;
4. as a silence self-heal: the watchdog detects the stream frame-silent for ≥ 10 min
   while system pointer/scroll HID activity is ≤ 60 s old and the screen is unlocked,
   rate-limited to at most one self-heal per 10 min.

Rebuilds SHALL be no-ops when no stream exists (no trackpad). A rebuild MUST NOT
introduce gesture false positives: self-heal only fires on a ≥ 10 min-silent stream
(no gesture can be in flight), and a truncated stroke tail after any rebuild is
strictly less likely to confirm than the full stroke.

##### Scenario: Stream dies without a system sleep
- WHEN the contact stream stops delivering frames while the user keeps using the
  machine (no system sleep occurs)
- THEN within ~10 min a watchdog rebuild restores gesture recognition without a
  relaunch

##### Scenario: Display topology change
- WHEN an external display is connected or disconnected
- THEN the stream is rebuilt within a few seconds and gestures keep working

##### Scenario: Healthy stream stays untouched
- WHEN frames are flowing normally
- THEN the watchdog performs no rebuilds (and logs nothing)

##### Scenario: System wake (regression guard)
- WHEN the Mac sleeps and later wakes
- THEN gestures resume within a couple of seconds with no relaunch
