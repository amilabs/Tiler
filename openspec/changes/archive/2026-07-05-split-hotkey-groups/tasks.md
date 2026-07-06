# Tasks — split-hotkey-groups
- [x] 1.1 SettingsStore: windowHotkeysEnabled (def false) + utilityHotkeysEnabled
      (def true), legacy key dropped (TDD).
- [x] 1.2 HotkeyController: per-group register/unregister; apply(window:utility:).
- [x] 1.3 AppDelegate wiring + "hotkeys configured" log; harness grep update;
      E2E enables the window group for its instance and restores after.
- [x] 1.4 Settings UI two toggles; Guide footnote about the default.
- [x] 1.5 Calibration sound on step transition and completion.
- [x] 1.6a 104 unit + 4/4 E2E green (doubleUp initial fail = live-user flake,
      passed on rerun); acceptance ALL PASS incl. new parked-cursor rule (hover
      animation self-stops after ~4 s). Installed.
- [x] 1.6b Merged specs; harness measurement windows lengthened to 20 s (0.01 s
      cputime resolution caused a false 1.00 % boundary failure — real post-UI is
      ~0.5-0.75 %); acceptance ALL PASS. Archived; released as v0.2.3.
