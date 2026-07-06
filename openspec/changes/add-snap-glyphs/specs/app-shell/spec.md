# app-shell — delta for add-snap-glyphs

## MODIFIED Requirements

#### Requirement: Unified About & Guide window (cheat-sheet glyphs)

Every hotkey and gesture row in the cheat sheet SHALL lead with a static placement
glyph: a screen outline with the target region drawn as a small window and a
directional chevron; next-display actions SHALL show two screens with the target on
the second; the ⌃A row SHALL show a padlock. Glyphs SHALL be non-animated (no idle
CPU, render deterministically in release screenshots).

##### Scenario: Placement is visible at a glance
- WHEN the unified window is open
- THEN each action shows a diagram of where the window will land, not text alone
