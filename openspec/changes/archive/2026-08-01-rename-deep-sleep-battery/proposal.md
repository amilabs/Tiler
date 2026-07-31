# rename-deep-sleep-battery

## Why

Field incident 2026-07-19 ~16:35 local: with the Deep Sleep profile on (enabled
07-18), the Mac hibernated from a plain IDLE sleep with the lid OPEN while another
macOS user was active — the owner expected hibernation only on lid close, matching
the toggle label "Deep Sleep on lid close". The mechanism cannot honor that label:
`hibernatemode 25` is per power source (battery), not per sleep cause — EVERY
battery sleep hibernates — and `pmset` custom profiles are machine-wide (every
user). The merged power spec already words it correctly ("governs how the Mac
sleeps whenever it actually sleeps on battery"); the UI label oversold the lid.

## What

Owner-approved 2026-08-01: rename the toggle to **"Deep Sleep on battery"** and
make the Settings + Guide + README copy state plainly: any sleep on battery
becomes hibernation — including idle sleep with the lid open — and the profile
applies to the whole Mac (all users). No behavior change; copy/spec only.

## Impact

- SettingsWindow (Power tab label + explanation), GuideWindow power section,
  README Prevent Sleep section; docs/screenshots/guide.png re-render.
- Specs: power "Deep Sleep profile (battery)" requirement wording; settings
  "Power tab" requirement label. Ships in v0.3.4.
