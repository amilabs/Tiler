# gestures — delta for add-thirds-lock-help

## MODIFIED Requirements

#### Requirement: Direction mapping and modifiers (extends Cmd mapping)

The recognizer SHALL snapshot both ⌘ and ⇧ at confirmation time. Mapping:
left/right emit half-width actions; with ⇧ held they emit third-width actions;
⌘ retargets either to the next display; ⇧ with up is ignored (plain maximize).

##### Scenario: Shift-held right swipe
- WHEN a valid 3-finger right swipe confirms while ⇧ is physically held
- THEN the window tiles to the right third of the current screen

##### Scenario: Shift+Cmd left swipe
- WHEN a valid left swipe confirms with both ⇧ and ⌘ held
- THEN the window tiles to the left third of the next display
