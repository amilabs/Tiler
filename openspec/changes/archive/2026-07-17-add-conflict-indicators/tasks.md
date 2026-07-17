# Tasks — add-conflict-indicators

- [x] 1. [USER GATE] Rendered mockups (menu warning states red/orange incl. the
      gestures-off gating, Gestures tab mark, menu-bar glyph behavior) → owner
      sign-off before any wiring. Honest constraint shown: macOS TabView cannot
      color tab text — tab mark is a label-colored "⚠︎" suffix.
- [x] 2. Implement per approved mocks: gesturesEnabled gate for all conflict
      marks; red/orange attributed "Settings ⚠︎"; tab title suffix; live refresh
      on settings change / menu open (existing refresh points).
- [x] 3. Spec deltas merged (app-shell menu/status alerts; settings tab mark);
      swift build && swift test + acceptance; remove throwaway mocks.
- [x] 4. Release v0.3.3, archive change, update pointers.
