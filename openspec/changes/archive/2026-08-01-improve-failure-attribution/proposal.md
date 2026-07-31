# improve-failure-attribution

## Why

Two 2026-08-01 diagnosis gaps, both owner-hit ("дописать лог" approved):

1. Eight `window … ok=false` lines after the 0.3.4 install were misattributed (by
   me) to a dropped Accessibility grant; the owner refuted it — he never touched
   the toggle, and moves work now, so the grant was there all along (it survives
   reinstalls: Apple Development cert → stable designated requirement; the
   "re-confirm after install" advice was self-signed-era folklore). The real
   cause — the frontmost app had no movable focused window — was invisible: the
   log had only `ok=false` with no why.
2. The up-swipe-vs-scroll reject lines (`reason=fingers fingers=2`) cannot
   distinguish a real mid-stroke finger lift from a contact filtered out by
   `minContactSize` (fingertip pressure drops on upward strokes) — the decision
   between lowering the size threshold and a dropout grace needs that datum.

## What

1. **Window-failure attribution**: `window <cmd> src=… ok=false` gains
   `why=no-frontmost-app|no-focused-window|frame-unreadable` and the frontmost
   app's bundle id (failures only). A real permission loss now shows up as
   `no-focused-window` against every app after an install — distinguishable by
   pattern — while a bare desktop shows the Finder id.
2. **Reject raw contact count**: `reject … fingers=N raw=M` — raw touching
   contacts before the size filter. `raw=3` with `fingers=2` proves the size
   filter cut a light fingertip; `raw=2` proves a physical lift.
3. **Docs de-folklore**: install.sh echo, project.md standing-order note, and
   memory no longer claim an Accessibility re-confirm is needed after installs
   (field-confirmed surviving, 2026-08-01).

## Impact

- GestureRecognizer (raw plumbed to reject lines, TDD), WindowActions
  (failure-detail API), AppDelegate execute() logging; power spec diagnostic
  logging updated. Ships as v0.3.5.
