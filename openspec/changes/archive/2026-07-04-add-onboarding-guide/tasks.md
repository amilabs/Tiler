# Tasks — add-onboarding-guide

- [x] 1.1 SettingsStore.hasSeenGuide (TDD).
- [x] 1.2 GuideContent: bindings/gestures reference data mirroring the specs.
- [x] 1.3 GuideWindow (SwiftUI): header, live permission card, keycap hotkey table,
      animated gesture table, troubleshooting (conflicts inline + Calibrate).
- [x] 1.4 AppDelegate: menu item Shortcuts & Help; startup flow v2 (first run or
      unpermitted → Guide); permission state pushed into GuideModel; --show-guide
      smoke arg.
- [x] 1.5 Owner eyeballed the Guide («Все отлично») with follow-ups, all done:
      richer About description, build time in LOCAL timezone (ISO stamp in
      Info.plist, formatted at display), conflict ALERTING (status-item ⚠︎ +
      tooltip, re-check on menu open, Guide-on-launch when conflicts present) —
      live-verified by toggling a real system setting and reverting.
- [x] 1.6 Specs merged (app-shell), change archived.
