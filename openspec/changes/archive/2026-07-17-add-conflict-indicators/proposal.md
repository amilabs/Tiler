# add-conflict-indicators

## Why

Field test on the macOS 15.1.1 laptop (2026-07-17) showed ConflictDiagnostics
catching real system 3-finger conflicts — but the only surfaces are the menu-bar ⚠
glyph (shared with the permission alert, monochrome) and the Settings → Gestures
tab content. Owner request (2026-07-17): conflicts must be visible as a mark on the
Gestures tab itself and in the menu at the same place as the permission warning —
but yellowish, not red — and none of it may distract when gestures are disabled in
the UI (a conflict is not critical if gestures are off).

## What

1. **Settings → Gestures tab**: warning mark on the tab item while conflicts exist
   and gestures are enabled. (macOS TabView tab items accept plain text/images
   only — no color, no badges — so the mark is a "⚠︎" title suffix in label color;
   the orange accent lives in the menu and the tab's conflict rows.)
2. **Menu**: the Settings item — which already carries "Settings ⚠︎" for the
   missing permission — distinguishes the two alerts by color: permission missing =
   red ⚠, gesture conflicts = orange ⚠ (matches the conflict rows' orange in the
   window). Permission wins when both apply.
3. **Gating**: every conflict-driven mark (menu-bar glyph contribution, menu item
   mark, tab mark) appears only while `gesturesEnabled` is on. Permission-driven
   marks are unaffected (permission also covers hotkeys/window actions).

## Impact

- AppDelegate: updateStatusGlyph/refreshConflictAlert gain the gesturesEnabled
  gate + attributed (colored) Settings title; SettingsModel/SettingsView: tab
  title suffix. Spec deltas: app-shell (menu/status alerts), settings (tab mark).
- UI change → [USER GATE] mockup approval BEFORE wiring (owner flow rule).
- Release as v0.3.3 together with any pending fixes.
