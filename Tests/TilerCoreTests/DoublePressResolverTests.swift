import Testing
@testable import TilerCore

// Ctrl+Shift+↑ disambiguation (hotkeys spec): wait ~300 ms; second press within the
// window → center-third immediately; window expiry with one press → maximize once.
@Suite("Double-press resolver") struct DoublePressResolverTests {
    let window = 0.300

    @Test func singlePressResolvesToMaximizeAfterWindow() {
        var resolver = DoublePressResolver(window: window)
        #expect(resolver.registerPress(at: 10.0) == nil)         // no decision yet
        #expect(resolver.resolveExpired(now: 10.2) == nil)       // window still open
        #expect(resolver.resolveExpired(now: 10.301) == .maximize)
        #expect(resolver.resolveExpired(now: 10.4) == nil)       // emitted exactly once
    }

    @Test func doublePressWithinWindowGivesCenterThirdImmediately() {
        var resolver = DoublePressResolver(window: window)
        #expect(resolver.registerPress(at: 10.0) == nil)
        #expect(resolver.registerPress(at: 10.15) == .centerThird)
        #expect(resolver.resolveExpired(now: 10.5) == nil)       // no trailing maximize
    }

    // Boundary uses 0.25 (exactly representable in binary floating point) — the
    // inclusive-≤ semantics are what's under test, not double rounding.
    @Test func secondPressExactlyAtWindowBoundaryIsADouble() {
        var resolver = DoublePressResolver(window: 0.25)
        #expect(resolver.registerPress(at: 10.0) == nil)
        #expect(resolver.registerPress(at: 10.25) == .centerThird)
    }

    @Test func pressesSpacedBeyondWindowGiveTwoMaximizes() {
        var resolver = DoublePressResolver(window: window)
        #expect(resolver.registerPress(at: 10.0) == nil)
        #expect(resolver.resolveExpired(now: 10.35) == .maximize)
        #expect(resolver.registerPress(at: 11.0) == nil)
        #expect(resolver.resolveExpired(now: 11.35) == .maximize)
    }

    @Test func afterDoubleTheNextPressStartsAFreshCycle() {
        var resolver = DoublePressResolver(window: window)
        _ = resolver.registerPress(at: 10.0)
        #expect(resolver.registerPress(at: 10.1) == .centerThird)
        #expect(resolver.registerPress(at: 10.15) == nil)        // press 3 = new cycle
        #expect(resolver.resolveExpired(now: 10.5) == .maximize)
    }

    // Defensive: if the driver never called resolveExpired (missed timer), a late
    // press must not be treated as a double.
    @Test func lateSecondPressAfterMissedExpiryIsNotADouble() {
        var resolver = DoublePressResolver(window: window)
        #expect(resolver.registerPress(at: 10.0) == nil)
        #expect(resolver.registerPress(at: 10.8) == nil)         // stale pending replaced
        #expect(resolver.resolveExpired(now: 11.2) == .maximize) // resolves the new press
    }

    @Test func deadlineReflectsPendingPress() {
        var resolver = DoublePressResolver(window: window)
        #expect(resolver.deadline == nil)
        _ = resolver.registerPress(at: 10.0)
        #expect(resolver.deadline == 10.3)
        _ = resolver.registerPress(at: 10.1)
        #expect(resolver.deadline == nil)                        // resolved, nothing pending
    }
}
