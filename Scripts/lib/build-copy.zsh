# How a developer script runs this checkout's build/Tiler.app without touching the
# owner's Tiler (fix-script-launch-isolation): launch it by absolute path with
# isolating settings, find and stop only that exact executable, and refuse to start
# while sleep is disabled. Sourced by Scripts/run-acceptance.sh and
# Scripts/record-golden.sh after they cd to the repository root; sourcing only
# defines the names below. Self-test: Scripts/lib/build-copy-test.zsh.

# The only executable the scripts launch: absolute, symlinks resolved.
TILER_BUILD_BIN="${PWD:A}/build/Tiler.app/Contents/MacOS/Tiler"

# pgrep/pkill -f match an extended regex against the space-joined argv. argv[0] is
# anchored to the escaped absolute path, so another checkout's build (which the old
# relative substring also hit), a relative launch, or a longer path never matches.
TILER_BUILD_PATTERN="^$(print -r -- "$TILER_BUILD_BIN" | sed 's/[][\.^$*+?(){}|]/\\&/g')( |\$)"

# Settings for the script's copy through the argument domain (process-local, never
# persisted): nothing in the owner's power-debug.log, and no window moves — the touch
# stream and the --record-touches recorder still run. `<false/>` arrives as a Bool; a
# bare NO is a String, which SettingsStore's `as? Bool` ignores. -powerDebugLogging
# mirrors TilerCopies.isolatedLaunchArguments (the hotkey E2E).
TILER_ISOLATED_ARGS=(-powerDebugLogging '<false/>' -gesturesEnabled '<false/>')

tiler_build_running() {
    pgrep -f "$TILER_BUILD_PATTERN" >/dev/null
}

# Always returns 0: callers may run under set -e, and nothing to stop is no error.
tiler_stop_build() {
    pkill -f "$TILER_BUILD_PATTERN" 2>/dev/null || true
    local i
    for i in {1..30}; do
        tiler_build_running || return 0
        sleep 0.1
    done
    return 0
}

# Same source as the app's DisableSleepGovernor.sleepDisabledNow() and the E2E guard.
tiler_sleep_disabled() {
    [[ "$(pmset -g | awk '/SleepDisabled/ { print $2 }')" == "1" ]]
}

# While sleep is disabled every launch opens the modal "Sleep is still disabled"
# alert, one click away from ending the owner's lid-closed session.
tiler_require_sleep_enabled() {
    tiler_sleep_disabled || return 0
    print -u2 -- 'REFUSED: sleep is disabled (pmset SleepDisabled 1) — every launch would open the "Sleep is still disabled" alert; run again after the lid-closed session ends or the flag is restored.'
    exit 2
}
