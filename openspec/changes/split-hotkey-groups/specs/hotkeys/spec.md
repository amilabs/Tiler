# hotkeys — delta for split-hotkey-groups

## MODIFIED Requirements

#### Requirement: Hotkey groups and defaults

Bindings SHALL be grouped: **window tiling** (all ⌃⇧ / ⌘⌃⇧ arrow bindings) and
**utility** (⌃A lock screen). Each group SHALL be independently toggleable from
Settings, registering/unregistering its Carbon hotkeys without relaunch and
persisting across restarts. Defaults: window tiling OFF, utility ON.

##### Scenario: Window hotkeys disabled by default
- WHEN Tiler runs with fresh settings
- THEN ⌃⇧-arrow combos reach other applications normally while ⌃A still locks
  the screen

##### Scenario: Independent toggles
- WHEN the window group is enabled and the utility group is disabled
- THEN arrows tile windows while ⌃A behaves as if Tiler were not running
