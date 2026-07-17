# Tasks — lower-macos-floor

Owner decision 2026-07-16: floor must not block the older fleet laptops
(hit on macOS 15.1.1). No user gates.

- [x] 1. Package.swift platforms → .macOS("15.0"); verify clean build and
      binary `minos 15.0` (availability probe).
- [x] 2. make-app.sh: LSMinimumSystemVersion 15.0; release build universal
      (arm64 + x86_64, `lipo`-verified); VERSION → 0.3.2 (+ AppDelegate.version).
- [x] 3. Full swift test (non-AX) + power-acceptance + run-acceptance on the
      signed universal .app.
- [x] 4. README requires-line + project.md tech-stack decision updated;
      release v0.3.2 (`gh release`), archive this change, update pointers.

Field result (owner's team, 2026-07-17, macOS 15.1.1 laptop, debug log +
screenshot): v0.3.2 launches; full gesture matrix works — left/right halves,
up→maximize, ⇧-third, ⌘-next-display, ⌘↑→none — every fire `fingers=3` with sane
speeds, every window move `ok=true`; calibration capture runs (fires logged as
`gesture ignored … calibrating=true` by design); ConflictDiagnostics correctly
flagged BOTH system 3-finger settings on that machine (horizontal full-screen
swipes + Mission Control/App Exposé) with the exact System Settings instructions.
Caveat given to the owner: until those are set to four fingers, macOS competes for
the same 3-finger swipes on that laptop.
