# hotkeys — delta for add-thirds-lock-help

## MODIFIED Requirements

#### Requirement: Fixed hotkey bindings (adds one)

| Input | Action |
|---|---|
| ⌃A | lock the screen |

The binding is registered like all others (Carbon, no event tap, honors the
Hotkeys toggle). Known trade-off, accepted by the owner: ⌃A shadows the
"beginning-of-line" shortcut system-wide while Tiler hotkeys are enabled.

##### Scenario: Lock screen
- WHEN ⌃A is pressed while Tiler hotkeys are enabled
- THEN the session locks (equivalent to the system Lock Screen), and unlocking
  returns with Tiler still running normally
