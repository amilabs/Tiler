# settings — delta for add-power-control

## MODIFIED Requirements

#### Requirement: Power tab

The Settings window SHALL gain a Power tab with: "Keep display awake" (default off),
the battery floor picker (Off / 30% / 20% / 10%, default 20%), and the "Deep Sleep on
lid close" toggle with a short explanation (full hibernate on battery sleep, wake
takes ~10–20 s, admin authorization on toggle). All controls persist across
relaunches and apply without restart, matching existing settings behavior. The tab
SHALL fit without vertical scrolling (existing no-scroll rule).

##### Scenario: Floor picker persists
- WHEN the user selects a 10% floor and relaunches Tiler
- THEN the picker still shows 10% and the floor is enforced for the next session

##### Scenario: Deep Sleep toggle reflects reality
- WHEN the pmset profile was changed outside Tiler
- THEN the toggle state after relaunch matches `pmset -g custom`, not the stale
  stored preference
