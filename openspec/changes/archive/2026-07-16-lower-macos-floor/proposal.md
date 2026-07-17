# lower-macos-floor

## Why

The owner's original brief pinned "target macOS 26 only" (brief.md:44), and the
floor was enforced via `Package.swift` `platforms: [.macOS("26.0")]` +
`LSMinimumSystemVersion 26.0`. Fleet testing (2026-07-16) hit it in the field: a
third laptop on macOS 15.1.1 (24B91) refuses to launch Tiler with "You can't use
this version of the application". Owner reversed the floor decision same day:
"а ты зачем запретил запуск на других версиях то? не было такого правила" — the
app must run on the older machines too.

## What

1. Deployment floor macOS 26.0 → **15.0** (Package.swift platforms +
   LSMinimumSystemVersion). Probe result: the entire codebase already compiles
   clean for a 15.0 target (zero availability errors — every API used predates 15),
   binary `minos 15.0`.
2. Release binary becomes **universal (arm64 + x86_64)** — the older fleet may
   include Intel Macs (Sequoia supports 2018+ Intel MacBooks); a universal slice
   costs one extra compile pass.
3. README requirement line and project.md tech-stack decision updated; the Guide
   footer keeps the spec-mandated honest note ("verified on macOS 26.5 only") —
   the floor changes, the verified configuration does not until another machine
   passes acceptance.
4. Release as **v0.3.2**.

## Risks / caveats

- Gesture recognition, window AX, hotkeys, IOKit assertions, MultitouchSupport
  private API: all ancient, stable across 15…26; recognition logic is
  OS-independent (pure frames→decisions).
- The x86_64 slice is compile-verified only (no Intel hardware here); the
  MultitouchSupport C struct layout is arch-identical (plain floats/ints, same
  alignment) and has been stable for over a decade.
- TCC on macOS 15 with an Apple Development cert is the ordinary path (the
  macOS-26 self-signed quirk documented in README does not apply backwards).
- Power features (pmset disablesleep / hibernatemode 25 / IOPM assertion keys)
  exist unchanged on 15; field verification happens on the older laptops —
  same honest-note policy as everything else.

## Spec impact

None: no merged requirement encodes the floor (the app-shell footer requirement
already anticipates "until another configuration passes acceptance"). README +
project.md carry the decision; this folder protocols it.

## Post-release clarification (owner, 2026-07-17)

Precise rule, owner verbatim: "Target OS действительно 26, то есть на других мы не
тестим (пока), но это не значит что надо запрещать запуск на них. Вот такое
правило." — i.e. the TARGET (and only tested) OS remains macOS 26; this change
removed only the launch prohibition on older versions, it did NOT move the target.
project.md "OS policy" carries this as the standing rule.
