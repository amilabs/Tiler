# app-shell — delta for add-power-control

## MODIFIED Requirements

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
timer whether the session is normal or lid-closed. While a session is active the main menu SHALL ALSO show a prominent
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

#### Requirement: Gesture recovery after system wake

The MultitouchSupport contact stream goes stale across a real system sleep (its
device refs die), so gestures stop working until relaunch. Tiler SHALL rebuild the
touch stream shortly after `NSWorkspace.didWakeNotification` (after a brief delay for
the HID stack to re-enumerate the trackpad), restoring gestures without a relaunch.
(Surfaced by the Deep Sleep test at gate 4.2, where a real 2 h hibernate left
gestures dead until the owner restarted the app.)

##### Scenario: Gestures work after a sleep/wake cycle
- WHEN the Mac sleeps and later wakes
- THEN gestures resume within a couple of seconds with no relaunch
