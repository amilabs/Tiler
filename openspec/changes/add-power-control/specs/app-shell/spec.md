# app-shell — delta for add-power-control

## MODIFIED Requirements

#### Requirement: Menu Power section

The status-item menu SHALL gain a Power section between the primary items and Quit:
a "Keep Awake" submenu (start indefinite, the seven fixed durations, the per-session
lid-closed ⚠ option, Stop) whose header line shows the active state and remaining
time. Menu state SHALL refresh when the menu opens (existing `menuWillOpen` path);
no live ticking is required while the menu is closed.

##### Scenario: Menu reflects the running session
- WHEN the menu opens 12 minutes into a 30-minute session
- THEN the Keep Awake entry shows an active marker and roughly "18 min left"

#### Requirement: Status item session state

While a session is active the status item SHALL show a compact additional indicator
(exact glyph per approved mockups), coexisting with the ⚠ permission/conflict marker.

##### Scenario: Session indicator
- WHEN a session is active and permissions are fine
- THEN the status item shows the session indicator and no ⚠
