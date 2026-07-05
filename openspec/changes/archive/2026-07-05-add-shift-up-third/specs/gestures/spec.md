# gestures — delta for add-shift-up-third

## MODIFIED Requirements

#### Requirement: Direction mapping and modifiers (⇧+up)

With ⇧ held, up SHALL emit a third-width up action (center-third: full height,
centered, ⅓ width — the double-press ↑ analog). ⌘ with up SHALL still emit nothing,
regardless of ⇧.

##### Scenario: Shift-held up swipe
- WHEN a valid 3-finger up swipe confirms while ⇧ is physically held
- THEN the window goes to full height, horizontally centered, ⅓ of the screen width
