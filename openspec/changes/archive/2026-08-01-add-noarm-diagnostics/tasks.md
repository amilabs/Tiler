# Tasks — add-noarm-diagnostics

Owner context 2026-08-01 ("hope the log helps" — translated): armed candidates are fine;
never-armed attempts are invisible. Diagnostic-only change.

- [x] 1. TDD: `noarm` line for saw-3-never-armed sessions (flicker case), none
      for clean fires / pure 2-finger scrolls; `near=` in reject lines
      (hovering third finger distinguishable from a fully-lifted one).
- [x] 2. Implement in GestureRecognizer (counters gated on diagnostic != nil);
      full tests green (golden traces untouched).
- [x] 3. Power spec diagnostic-logging merged; release v0.3.6 + local install;
      archive.
