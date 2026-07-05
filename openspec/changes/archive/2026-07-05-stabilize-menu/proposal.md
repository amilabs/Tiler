# Change: stabilize-menu

## Why

Owner course-correction after living with the single-entry menu: Settings must be
reachable directly from the status menu, and the menu itself must surface the
Accessibility problem. Goal: settle the final, stable menu layout and stop UI churn.

## What Changes

- Menu (final): **Tiler…** (unified About & Guide) / **Settings… (⌘,)** / **Quit**.
- The Settings item SHALL carry a visible ⚠︎ marker whenever Accessibility is
  missing (in addition to the status-item alert glyph and tooltip).
- Stability pass: full suite + acceptance re-run on the settled layout.

## Capabilities affected

| Capability | Delta |
|---|---|
| `app-shell` | MODIFIED — final menu list + alert marker on the Settings item |
