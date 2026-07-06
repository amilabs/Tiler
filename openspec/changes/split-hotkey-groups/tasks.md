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
- [ ] 1.6b Owner gate; merge, archive, release.
