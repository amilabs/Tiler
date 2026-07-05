# window-actions — delta for add-thirds-lock-help

## MODIFIED Requirements

#### Requirement: Tiling geometries (adds thirds)

Left/right THIRD SHALL fill exactly one third of the visible frame (leftmost or
rightmost respectively), full height, on the current or next display — same
placement rules and workarounds as halves.

##### Scenario: Right third
- WHEN the right-third action targets a window
- THEN its frame equals the rightmost third of the screen's visible frame

#### Requirement: Lock-screen command

A lockScreen command SHALL lock the user session using the system lock
(private `SACLockScreenImmediate`, falling back to `CGSession -suspend`);
it requires no Accessibility permission and never crashes on failure.
