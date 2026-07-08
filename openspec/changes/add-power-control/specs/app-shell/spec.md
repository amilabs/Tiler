# app-shell — delta for add-power-control

## MODIFIED Requirements

#### Requirement: Menu Power section

The status-item menu SHALL gain a Power section between the primary items and Quit:
a "Prevent Sleep" submenu (start indefinite, the seven fixed durations, the
per-session lid-closed ⚠ option, Stop) whose header line shows the active state and
remaining time. While a session is active the main menu SHALL ALSO show a prominent
row at its very top (bold, with the red cup mark) stating the feature and the
remaining time / lid-closed state (owner request 2026-07-08); the row is hidden when
inactive. Menu state SHALL refresh when the menu opens (existing `menuWillOpen` path);
for a timed session the top row and header SHALL tick live (once per second) while the
menu is open, but no ticking is required while the menu is closed.

##### Scenario: Menu reflects the running session
- WHEN the menu opens 12 minutes into a 30-minute session
- THEN a prominent top row and the submenu header both show roughly "18 min left",
  updating each second while the menu stays open

#### Requirement: Status item session state

While a session is active the status item SHALL show the monochrome hand glyph badged
with a solid red disc + white cup silhouette at its bottom-right (approved mockup,
gate 2.1), coexisting with the ⚠ permission/conflict marker; the badge is re-rendered
only when the active state or the menu-bar appearance changes.

##### Scenario: Session indicator
- WHEN a session is active and permissions are fine
- THEN the status item shows the red-cup badge and no ⚠
