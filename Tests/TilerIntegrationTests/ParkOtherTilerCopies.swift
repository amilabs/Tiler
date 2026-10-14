import Foundation
import Testing
@testable import TilerSystem

/// Suite-scoped (fix-e2e-test-isolation; owner decision 2026-10-14, translated: "close
/// and relaunch"): parks every other running Tiler copy for the whole hotkey E2E, so
/// only the build under test holds the hotkeys, then relaunches each one. A detached
/// sentinel relaunches them if this test process dies first (crash, Ctrl-C, a tool
/// timeout); when the in-process relaunch fails it stays armed as a second attempt.
struct ParkOtherTilerCopies: SuiteTrait, TestScoping {
    struct Refused: Error, CustomStringConvertible {
        let description: String
    }

    func provideScope(
        for test: Test, testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        // The suite's skip conditions ran at planning, up to a minute ago.
        if TilerCopies.otherCopyHoldsPowerAssertion() || DisableSleepGovernor.sleepDisabledNow() {
            throw Refused(description: "a Prevent Sleep session started after planning; not parking Tiler")
        }
        if TilerCopies.anotherCheckoutsBuildRuns() {
            throw Refused(description: "another checkout's build started after planning; not parking it")
        }
        let bundles = TilerCopies.otherCopies().compactMap(\.bundleURL)
        // Armed even with nothing to relaunch: it still stops a build under test that
        // outlives a killed runner.
        let sentinel = TilerCopies.armSentinel(
            watching: getpid(), run: TilerCopies.relaunchCommand(stopping: TilerCopies.buildBinary, thenOpening: bundles))
        let parked = await TilerCopies.parkOtherCopies()

        var failure: (any Error)?
        do { try await function() } catch { failure = error }

        await TilerCopies.stopBuildUnderTest()
        let missing = await TilerCopies.relaunch(parked)
        if missing.isEmpty {
            sentinel?.disarm()
        } else {
            let paths = missing.map(\.path).joined(separator: ", ")
            Issue.record("not relaunched after the hotkey E2E: \(paths); the sentinel retries at process exit")
        }
        if let failure { throw failure }
    }
}

extension Trait where Self == ParkOtherTilerCopies {
    static var parkingOtherTilerCopies: Self { Self() }
}
