# hotkeys — delta for add-shell-and-calibration

## MODIFIED Requirements

#### Requirement: Registration is independent of Accessibility permission (modified)

Additionally, hotkeys SHALL be globally toggleable from Settings: when disabled,
Tiler unregisters its Carbon hotkeys (so the combos reach other apps normally) and
re-registers them when re-enabled, persisting the choice across relaunches.

##### Scenario: Toggle releases the key combos
- WHEN hotkeys are disabled in Settings
- THEN Ctrl+Shift+arrows behave as if Tiler were not running, and re-enabling restores
  Tiler's handling without relaunch
