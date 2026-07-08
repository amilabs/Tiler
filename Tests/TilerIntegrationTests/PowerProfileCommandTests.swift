import Foundation
import Testing
@testable import TilerSystem

// Deep Sleep pmset command composition (power spec). Battery-side only (`pmset -b`);
// proximitywake is touched only where the key exists; restore writes snapshotted
// values verbatim, or Apple portable defaults when the snapshot is empty.
@Suite("Power profile commands") struct PowerProfileCommandTests {

    @Test func applyWithoutProximitywake() {
        let current = ["hibernatemode": "3", "powernap": "0", "tcpkeepalive": "0"]
        #expect(PowerProfileController.applyCommand(current: current)
                == "pmset -b hibernatemode 25 powernap 0 tcpkeepalive 0")
    }

    @Test func applyAppendsProximitywakeWhenPresent() {
        let current = ["hibernatemode": "3", "proximitywake": "1"]
        #expect(PowerProfileController.applyCommand(current: current)
                == "pmset -b hibernatemode 25 powernap 0 tcpkeepalive 0 proximitywake 0")
    }

    @Test func restoreWritesSnapshotVerbatim() {
        let snapshot = ["hibernatemode": "3", "powernap": "0", "tcpkeepalive": "0"]
        #expect(PowerProfileController.restoreCommand(snapshot: snapshot)
                == "pmset -b hibernatemode 3 powernap 0 tcpkeepalive 0")
    }

    @Test func restoreIncludesProximitywakeFromSnapshot() {
        let snapshot = ["hibernatemode": "0", "powernap": "1", "tcpkeepalive": "1", "proximitywake": "1"]
        #expect(PowerProfileController.restoreCommand(snapshot: snapshot)
                == "pmset -b hibernatemode 0 powernap 1 tcpkeepalive 1 proximitywake 1")
    }

    @Test func restoreEmptySnapshotUsesPortableDefaults() {
        #expect(PowerProfileController.restoreCommand(snapshot: [:])
                == "pmset -b hibernatemode 3 powernap 1 tcpkeepalive 1")
    }
}
