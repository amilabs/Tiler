# app-shell — delta for stabilize-menu

## MODIFIED Requirements

#### Requirement: Menu-bar-only application (modified — final layout)

The menu SHALL contain exactly: **Tiler…** (unified About & Guide window),
**Settings… (⌘,)**, and **Quit**. When Accessibility is missing, the Settings item
SHALL show a visible ⚠︎ marker (the status item keeps its alert glyph + tooltip).

##### Scenario: Settings item alerts on missing permission
- WHEN the menu opens while Accessibility is not granted
- THEN the Settings item visibly carries the alert marker, and it clears once the
  permission is granted
