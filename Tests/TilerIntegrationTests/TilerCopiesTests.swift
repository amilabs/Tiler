import Foundation
import IOKit.pwr_mgt
import Testing

// Hotkey E2E isolation (fix-e2e-test-isolation): which running Tiler copies the suite
// may stop, how a live Prevent Sleep session is detected, and the crash backstop that
// relaunches parked copies. None of this needs Accessibility.
@Suite("Tiler copies (E2E isolation)")
struct TilerCopiesTests {
    private let build = URL(fileURLWithPath: "/Users/x/Tiler/build/Tiler.app/Contents/MacOS/Tiler")

    // MARK: - Which copy is the build under test

    @Test func theExactBuildPathIsTheBuildUnderTest() {
        #expect(TilerCopies.isBuildUnderTest(build, buildBinary: build))
        let unnormalized = URL(fileURLWithPath: "/Users/x/Tiler/build/../build/Tiler.app/Contents/MacOS/Tiler")
        #expect(TilerCopies.isBuildUnderTest(unnormalized, buildBinary: build))
    }

    /// The 2026-10-14 bug: a name pattern also matched the owner's installed copy.
    @Test func installedAndOtherCheckoutCopiesAreNeverTheBuildUnderTest() {
        let installed = URL(fileURLWithPath: "/Users/x/Applications/Tiler.app/Contents/MacOS/Tiler")
        let otherCheckout = URL(
            fileURLWithPath: "/Users/x/Tiler/.claude/worktrees/w/build/Tiler.app/Contents/MacOS/Tiler")
        #expect(!TilerCopies.isBuildUnderTest(installed, buildBinary: build))
        #expect(!TilerCopies.isBuildUnderTest(otherCheckout, buildBinary: build))
        #expect(!TilerCopies.isBuildUnderTest(nil, buildBinary: build))
    }

    // MARK: - Live session detection

    /// Every Prevent Sleep session holds an IOPM assertion; the lookup must attribute
    /// one to the process that created it, and drop it once released.
    @Test func powerAssertionsAreAttributedToTheirProcess() async throws {
        var id = IOPMAssertionID(0)
        let created = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Tiler tests: assertion attribution probe" as CFString, &id)
        try #require(created == kIOReturnSuccess)
        #expect(TilerCopies.pidsHoldingPowerAssertions().contains(getpid()))

        IOPMAssertionRelease(id)
        var released = false
        for _ in 0..<20 where !released {
            released = !TilerCopies.pidsHoldingPowerAssertions().contains(getpid())
            if !released { try await Task.sleep(for: .milliseconds(50)) }
        }
        #expect(released, "the released assertion is still attributed to this process")
    }

    // MARK: - Relaunch sentinel

    private func temporaryMarker() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("tiler-sentinel-\(UUID().uuidString)")
    }

    private func waitForFile(_ url: URL, seconds: Double) async throws -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            try await Task.sleep(for: .milliseconds(100))
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func startWatched(seconds: String) throws -> Process {
        let watched = Process()
        watched.executableURL = URL(fileURLWithPath: "/bin/sleep")
        watched.arguments = [seconds]
        try watched.run()
        return watched
    }

    @Test func sentinelRunsItsCommandOnceTheWatchedProcessIsGone() async throws {
        let marker = temporaryMarker()
        defer { try? FileManager.default.removeItem(at: marker) }
        let watched = try startWatched(seconds: "0.3")
        let sentinel = try #require(
            TilerCopies.armSentinel(watching: watched.processIdentifier, run: ["/usr/bin/touch", marker.path]))
        defer { sentinel.disarm() }
        #expect(!FileManager.default.fileExists(atPath: marker.path), "fired while the watched process lived")
        watched.waitUntilExit()  // reap it: a zombie still answers kill -0
        #expect(try await waitForFile(marker, seconds: 4), "sentinel never ran its command")
    }

    @Test func disarmedSentinelNeverRunsItsCommand() async throws {
        let marker = temporaryMarker()
        defer { try? FileManager.default.removeItem(at: marker) }
        let watched = try startWatched(seconds: "30")
        let sentinel = try #require(
            TilerCopies.armSentinel(watching: watched.processIdentifier, run: ["/usr/bin/touch", marker.path]))
        sentinel.disarm()
        watched.terminate()
        watched.waitUntilExit()
        #expect(!(try await waitForFile(marker, seconds: 2.5)), "a disarmed sentinel still fired")
    }

    /// Ctrl-C and tool timeouts signal the whole process group of the test run; the
    /// sentinel must sit outside it to survive and do its job.
    @Test func sentinelRunsInItsOwnSessionOutsideTheTestRunsProcessGroup() throws {
        let watched = try startWatched(seconds: "30")
        defer {
            watched.terminate()
            watched.waitUntilExit()
        }
        let sentinel = try #require(
            TilerCopies.armSentinel(watching: watched.processIdentifier, run: ["/usr/bin/true"]))
        defer { sentinel.disarm() }
        #expect(getsid(sentinel.pid) == sentinel.pid)
        #expect(getpgid(sentinel.pid) != getpgrp())
    }
}
