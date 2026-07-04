import Foundation
import Testing
@testable import TilerSystem

// Permission lifecycle logic with an injected trust check — no real TCC involved.
@MainActor
@Suite("Permission monitor") struct PermissionMonitorTests {
    @MainActor final class TrustFlag {
        var value = false
    }

    private func makeMonitor(_ flag: TrustFlag, changes: @escaping @MainActor (Bool) -> Void)
        -> PermissionMonitor {
        PermissionMonitor(pollInterval: 9999,
                          check: { flag.value },
                          onChange: { changes($0) })
    }

    @Test func startsUntrustedPollsAndRecoversOnGrantWithoutRestart() {
        let flag = TrustFlag()
        var changes: [Bool] = []
        let monitor = makeMonitor(flag) { changes.append($0) }
        monitor.start()
        #expect(changes == [false])
        #expect(monitor.isPolling)

        flag.value = true      // user grants in System Settings
        monitor.tick()         // next poll notices
        #expect(changes == [false, true])
        #expect(monitor.trusted)
        #expect(!monitor.isPolling)  // no polling while healthy (idle CPU budget)
    }

    @Test func startsTrustedWithoutPolling() {
        let flag = TrustFlag()
        flag.value = true
        var changes: [Bool] = []
        let monitor = makeMonitor(flag) { changes.append($0) }
        monitor.start()
        #expect(changes == [true])
        #expect(!monitor.isPolling)
    }

    @Test func revocationDetectedViaFailedActionResumesPolling() {
        let flag = TrustFlag()
        flag.value = true
        var changes: [Bool] = []
        let monitor = makeMonitor(flag) { changes.append($0) }
        monitor.start()

        flag.value = false     // tccutil reset / manual revoke
        monitor.noteActionFailed()
        #expect(changes == [true, false])
        #expect(!monitor.trusted)
        #expect(monitor.isPolling)
    }

    @Test func unchangedStateProducesNoSpuriousCallbacks() {
        let flag = TrustFlag()
        var changes: [Bool] = []
        let monitor = makeMonitor(flag) { changes.append($0) }
        monitor.start()
        monitor.tick()
        monitor.tick()
        #expect(changes == [false])
    }
}
