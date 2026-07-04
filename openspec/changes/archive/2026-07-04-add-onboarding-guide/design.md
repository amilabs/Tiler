# Design — add-onboarding-guide

Small change; decisions:

- **One window, sections stacked** (~560 pt wide): header (icon + tagline) →
  permission card → hotkeys table → gestures table → troubleshooting. No wizard,
  no pagination — the whole value is glanceability.
- **Cheat sheet is generated from constants** mirroring the specs (single source
  in `GuideContent`), not hand-written per-row views — adding a binding later
  touches one array.
- **Keycaps**: rounded-rect chips per key token (⌃⇧←). Gestures reuse
  `GestureDemoView` at ~44 pt height for live direction animation; Cmd variants
  shown as ⌘ + demo.
- **Permission card is live**: bound to the same PermissionMonitor pipeline as the
  status item (AppDelegate pushes state into GuideModel), so granting flips the
  card without relaunch — same mechanism the permissions spec already guarantees.
- **First-run flag**: `SettingsStore.hasSeenGuide` (UserDefaults-backed, TDD like
  the other settings). Startup: `if !hasSeenGuide || !trusted → showGuide()`;
  `hasSeenGuide` set true when the Guide first opens.
- Menu order: About / Shortcuts & Help / Settings… / Quit (⌘, stays on Settings).
