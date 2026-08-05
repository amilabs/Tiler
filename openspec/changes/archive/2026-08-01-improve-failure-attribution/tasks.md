# Tasks — improve-failure-attribution

Owner 2026-08-01, translated: "extend the log" + refutation of the permission theory (never
re-granted; grant survives installs).

- [x] 1. TDD: reject lines carry `raw=M`; new test — a sub-size third contact
      yields `fingers=2 raw=3` (the size-filter discriminator).
- [x] 2. WindowActions: failure detail (no-frontmost-app / no-focused-window /
      frame-unreadable); AppDelegate logs `ok=false why=… app=<bundle id>`.
- [x] 3. Docs/memory: drop the stale "re-confirm Accessibility after install"
      advice everywhere (install.sh echo, project.md, memory).
- [x] 4. Specs (power diagnostic logging) merged; build/tests/acceptance;
      release v0.3.5 + local install; archive.
