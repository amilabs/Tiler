# Change: unify-about-guide

## Why

Owner feedback after add-onboarding-guide: About should tell the product story
("о чём, зачем, какие жесты") in a marketing-quality way, with animation, and About
and Shortcuts & Help should be ONE window rather than two overlapping ones.

## What Changes

- One unified window ("About Tiler"): animated hero (cycling gesture demo) +
  tagline, three value bullets grounded in the original brief (trust/no false
  positives, per-hand calibration, featherweight resilience), the live permission
  card, the full hotkey/gesture cheat sheet, troubleshooting, and a footer with
  version, local-time build stamp, and the GitHub link.
- Menu shrinks to: About Tiler / Settings… / Quit (About opens the unified window;
  the separate Shortcuts & Help item and the old small About window are removed).
- Startup flow and --show-guide/--show-about smoke args land on the same window.

## Capabilities affected

| Capability | Delta |
|---|---|
| `app-shell` | MODIFIED — menu list; About window and Guide window requirements merge into one |
