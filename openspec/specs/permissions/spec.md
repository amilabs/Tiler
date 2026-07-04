# permissions — current spec (merged from add-tiler-mvp, 2026-07-04)

## Requirements

#### Requirement: Alive and safe without Accessibility permission

When Accessibility permission is not granted, Tiler SHALL keep running (menu bar alive),
SHALL NOT move windows, SHALL NOT crash, and SHALL NOT disturb or disable systemwide
input in any way. A visible warning state SHALL be shown in the menu bar.

##### Scenario: Launch without permission
- WHEN Tiler launches without AX permission
- THEN it prompts once via `AXIsProcessTrustedWithOptions`, stays alive, shows the warning
  state, and hotkeys/gestures are registered but act as no-ops

##### Scenario: Gesture/hotkey while unpermitted
- WHEN a valid gesture or hotkey fires without AX permission
- THEN no window moves and Tiler remains stable

#### Requirement: Recovery without restart

While permission is missing, Tiler SHALL poll `AXIsProcessTrusted()` every
`permissionPollSec` (~2 s). Once granted, full functionality SHALL resume without
relaunching, and the warning state SHALL clear.

##### Scenario: Grant while running
- WHEN the user grants Accessibility in System Settings while Tiler is running
- THEN within a few seconds hotkeys and gestures start moving windows and the warning clears

#### Requirement: No polling when healthy

Once permission is granted, the permission poll timer SHALL stop (contributes to the
idle-CPU budget). Permission loss (revocation) SHALL be detected on the next failed AX
action and re-enter the warning/poll state instead of crashing.

##### Scenario: Revocation while running
- WHEN AX permission is revoked (e.g., `tccutil reset`) while Tiler runs
- THEN the next action fails soft, the warning state returns, polling resumes, no crash
