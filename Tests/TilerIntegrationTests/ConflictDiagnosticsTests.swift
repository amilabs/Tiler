import Testing
@testable import TilerSystem

// Conflict detection over injected preference values — no real defaults touched.
@Suite("Conflict diagnostics") struct ConflictDiagnosticsTests {

    private func diagnostics(_ values: [String: Int]) -> ConflictDiagnostics {
        ConflictDiagnostics(reader: { domain, key in values["\(domain)/\(key)"] })
    }

    @Test func cleanSystemReportsNoConflicts() {
        #expect(diagnostics([:]).conflicts().isEmpty)
        #expect(diagnostics([
            "com.apple.AppleMultitouchTrackpad/TrackpadThreeFingerDrag": 0,
            "com.apple.AppleMultitouchTrackpad/TrackpadThreeFingerHorizSwipeGesture": 0,
            "com.apple.AppleMultitouchTrackpad/TrackpadThreeFingerVertSwipeGesture": 0,
        ]).conflicts().isEmpty)
    }

    @Test func threeFingerDragIsAConflict() {
        let found = diagnostics(
            ["com.apple.AppleMultitouchTrackpad/TrackpadThreeFingerDrag": 1]
        ).conflicts()
        #expect(found.count == 1)
        #expect(found[0].title.contains("Three Finger Drag"))
    }

    @Test func systemThreeFingerSwipesAreConflicts() {
        let found = diagnostics([
            "com.apple.AppleMultitouchTrackpad/TrackpadThreeFingerHorizSwipeGesture": 2,
            "com.apple.AppleMultitouchTrackpad/TrackpadThreeFingerVertSwipeGesture": 2,
        ]).conflicts()
        #expect(found.count == 2)
    }

    // Magic Trackpad settings live in a separate domain and must be checked too.
    @Test func bluetoothTrackpadDomainIsChecked() {
        let found = diagnostics(
            ["com.apple.driver.AppleBluetoothMultitouch.trackpad/TrackpadThreeFingerDrag": 1]
        ).conflicts()
        #expect(found.count == 1)
    }
}
