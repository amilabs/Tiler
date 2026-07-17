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
