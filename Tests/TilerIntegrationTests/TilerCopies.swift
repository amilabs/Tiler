import AppKit
import IOKit.pwr_mgt

/// The hotkey E2E's view of running Tiler copies (fix-e2e-test-isolation). The suite
/// launches this checkout's `build/Tiler.app` and may stop only that build; every other
/// copy — normally the owner's installed app — is parked (quit) for the suite and
/// relaunched afterwards, never just killed. Kept free of Testing and TilerSystem so the
/// park/relaunch path can be exercised against a decoy app outside the test runner.
enum TilerCopies {
    static let bundleID = "pro.amilabs.tilerx"

    /// This checkout's build. Derived from this file's path (cwd is unreliable under
    /// `swift test`): Tests/TilerIntegrationTests/TilerCopies.swift → up 3.
    static let buildBinary: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // TilerIntegrationTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // package root
        .appendingPathComponent("build/Tiler.app/Contents/MacOS/Tiler")

    static var isBuilt: Bool { FileManager.default.isExecutableFile(atPath: buildBinary.path) }

    /// Settings for the build under test, passed as launch arguments: the argument
    /// domain overrides the owner's stored values for that process only, so nothing is
    /// written to `pro.amilabs.tilerx` and nothing needs restoring. `-key YES` would
    /// arrive as the String "YES" (SettingsStore reads `as? Bool`); `<true/>` is a Bool.
    /// Debug logging off keeps test launches out of the owner's power-debug.log.
    static let isolatedLaunchArguments = [
        "-windowHotkeysEnabled", "<true/>",
        "-powerDebugLogging", "<false/>",
    ]

    // MARK: - Which copy is which

    /// Exact executable match — never a name pattern, which also hit the installed copy.
    static func isBuildUnderTest(_ executable: URL?, buildBinary: URL = buildBinary) -> Bool {
        guard let executable else { return false }
        return canonicalPath(executable) == canonicalPath(buildBinary)
    }

    private static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// Another checkout's `build/Tiler.app` (another session's E2E or acceptance script).
    /// It runs on launch arguments a relaunch could not restore, so it is never parked:
    /// the suite skips while one runs.
    static func isAnotherCheckoutsBuild(_ bundle: URL?, buildBinary: URL = buildBinary) -> Bool {
        guard let bundle else { return false }
        let path = canonicalPath(bundle)
        let ownBundle = canonicalPath(
            buildBinary.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
        return path.hasSuffix("/build/Tiler.app") && path != ownBundle
    }

    static func anotherCheckoutsBuildRuns(bundleID: String = bundleID) -> Bool {
        otherCopies(bundleID: bundleID).contains { isAnotherCheckoutsBuild($0.bundleURL) }
    }

    /// A fresh LaunchServices query (NSWorkspace.runningApplications only refreshes
    /// while a main run loop spins, which the test runner does not guarantee).
    static func otherCopies(bundleID: String = bundleID, buildBinary: URL = buildBinary) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { !isBuildUnderTest($0.executableURL, buildBinary: buildBinary) }
    }

    // MARK: - Live session detection

    /// PIDs that hold any IOPM power assertion. Every Prevent Sleep session holds one
    /// (idle/display/system); matching any assertion rather than Tiler's names survives
    /// a rename, and a stray extra one only costs a skipped E2E run.
    static func pidsHoldingPowerAssertions() -> Set<pid_t> {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
            let byPID = raw?.takeRetainedValue() as? [NSNumber: [Any]]
        else { return [] }
        return Set(byPID.compactMap { $0.value.isEmpty ? nil : $0.key.int32Value })
    }

    static func otherCopyHoldsPowerAssertion(bundleID: String = bundleID) -> Bool {
        let holders = pidsHoldingPowerAssertions()
        return otherCopies(bundleID: bundleID).contains { holders.contains($0.processIdentifier) }
    }

    // MARK: - Stop / park / relaunch

    /// Ground truth from the kernel (`isTerminated` also waits on the main run loop).
    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private static func waitUntilGone(_ pid: pid_t, seconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while isAlive(pid), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return !isAlive(pid)
    }

    /// Stops leftovers of this checkout's build (e.g. from a crashed earlier run) —
    /// the only copies the suite may stop outright.
    static func stopBuildUnderTest(bundleID: String = bundleID, buildBinary: URL = buildBinary) async {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where isBuildUnderTest(app.executableURL, buildBinary: buildBinary) {
            app.forceTerminate()
            _ = await waitUntilGone(app.processIdentifier, seconds: 3)
        }
    }

    /// Quits every other copy (Tiler has no quit confirmation; force after 5 s) and
    /// returns their bundle URLs for `relaunch`.
    static func parkOtherCopies(bundleID: String = bundleID, buildBinary: URL = buildBinary) async -> [URL] {
        var parked: [URL] = []
        for app in otherCopies(bundleID: bundleID, buildBinary: buildBinary) {
            guard let bundle = app.bundleURL else { continue }
            let pid = app.processIdentifier
            if !app.terminate() { app.forceTerminate() }
            if !(await waitUntilGone(pid, seconds: 5)) {
                app.forceTerminate()
                _ = await waitUntilGone(pid, seconds: 3)
            }
            parked.append(bundle)
        }
        return parked
    }

    private static func notRunning(_ bundles: [URL], bundleID: String) -> [URL] {
        let running = Set(
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .compactMap { $0.bundleURL.map(canonicalPath) })
        return bundles.filter { !running.contains(canonicalPath($0)) }
    }

    /// Relaunches parked bundles that are not running again yet; returns those still not
    /// running afterwards. Without `createsNewApplicationInstance`, NSWorkspace hands back
    /// any running app with the same bundle id (e.g. a dying build under test) and starts
    /// nothing — probed 2026-10-14 on decoy copies — so the flag is set, and the
    /// not-running filter keeps it from ever starting a second instance of a copy.
    static func relaunch(_ bundles: [URL], bundleID: String = bundleID, seconds: Double = 10) async -> [URL] {
        for bundle in notRunning(bundles, bundleID: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.addsToRecentItems = false
            config.createsNewApplicationInstance = true
            // Typed on purpose: untyped, Swift 6.4 resolves this to the fire-and-forget
            // completion-handler overload (nullable handler, default nil).
            let _: NSRunningApplication? = try? await NSWorkspace.shared.openApplication(
                at: bundle, configuration: config)
        }
        let deadline = Date().addingTimeInterval(seconds)
        while true {
            let missing = notRunning(bundles, bundleID: bundleID)
            if missing.isEmpty || Date() >= deadline { return missing }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    // MARK: - Crash backstop

    /// A detached shell that runs `command` once the watched process is gone. Spawned
    /// in its own session (POSIX_SPAWN_SETSID) with stdio on /dev/null, so a Ctrl-C or
    /// a process-group kill of the test run does not reach it and it holds no pipe of
    /// the runner open.
    struct Sentinel {
        let pid: pid_t

        func disarm() {
            kill(pid, SIGKILL)
            var status: Int32 = 0
            waitpid(pid, &status, 0)
        }
    }

    /// The sentinel's command: first SIGKILL any surviving copy of `build` (it outlives a
    /// runner killed alone and would keep the hotkeys), matched by its anchored, escaped
    /// path like Scripts/lib/build-copy.zsh, then `open -g` the parked bundles.
    static func relaunchCommand(stopping build: URL, thenOpening bundles: [URL]) -> [String] {
        let escaped = build.path.map { #"[]\.^$*+?(){}|"#.contains($0) ? "\\\($0)" : "\($0)" }.joined()
        let script = #"/usr/bin/pkill -9 -f "$1"; shift; [ $# -eq 0 ] || exec /usr/bin/open -g "$@""#
        return ["/bin/sh", "-c", script, "tiler-e2e-relaunch", "^\(escaped)( |$)"] + bundles.map(\.path)
    }

    static func armSentinel(watching watched: pid_t, run command: [String]) -> Sentinel? {
        let script = #"while kill -0 "$1" 2>/dev/null; do sleep 1; done; shift; exec "$@""#
        let argv = ["/bin/sh", "-c", script, "tiler-e2e-sentinel", String(watched)] + command

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID))

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)

        let cArgs = argv.map { strdup($0) } + [nil]
        defer { cArgs.forEach { free($0) } }
        var pid: pid_t = 0
        guard posix_spawn(&pid, "/bin/sh", &actions, &attributes, cArgs, environ) == 0 else { return nil }
        return Sentinel(pid: pid)
    }
}
