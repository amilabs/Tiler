# power — delta for improve-failure-attribution

## MODIFIED Requirements

#### Requirement: Diagnostic logging

(Additions only.) Reject lines SHALL also carry `raw=M` — the raw touching-contact
count before the size filter — so `fingers=2 raw=3` proves a fingertip cut by
`minContactSize` while `raw=2` proves a physical lift (the up-swipe-vs-scroll
discriminator, owner report 2026-08-01). Window-move failures SHALL be
attributable: `window <cmd> src=… ok=false` carries
`why=no-frontmost-app|no-focused-window|frame-unreadable` and the frontmost app's
bundle id (failures only; successes stay unchanged) — eight bare `ok=false` lines
after the 0.3.4 install were misread as a permission loss when the real cause was
a bare desktop with no focused window.

##### Scenario: A failed move names its cause
- WHEN a gesture fires while the frontmost app has no movable focused window
- THEN the log shows `ok=false why=no-focused-window app=<bundle id>` — not a bare
  `ok=false`
