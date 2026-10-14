#!/bin/zsh
# Self-test for Scripts/lib/build-copy.zsh (fix-script-launch-isolation). The helper
# must find and stop only this checkout's build — never another checkout's build, a
# relative launch, a longer path or a path that merely ends with this one — and must
# refuse to start while sleep is disabled. Runs compiled sleeper decoys in a temp dir;
# touches no real Tiler copy. Exits non-zero on any failure.
set -uo pipefail

HELPER="${0:A:h}/build-copy.zsh"
TMP="$(mktemp -d -t tiler-build-copy-test)"
PIDS=()
FAIL=0
cleanup() {
    for pid in $PIDS; do kill -9 "$pid" 2>/dev/null; done
    rm -rf "$TMP"
}
trap cleanup EXIT

check() { # $1 = 0/1, $2 = label
    if [[ "$1" == "0" ]]; then echo "PASS: $2"; else echo "FAIL: $2"; FAIL=1; fi
}

# A killed child stays a zombie until the shell reaps it; kill -0 would call it alive.
alive() {
    local state
    state=$(ps -o stat= -p "$1" 2>/dev/null) || return 1
    [[ "$state" != Z* ]]
}

# Like the app, a decoy takes a moment to quit on SIGTERM (0.6 s), so the stop must wait.
print -r -- '#include <signal.h>
#include <unistd.h>
static volatile sig_atomic_t term = 0;
static void on_term(int sig) { (void)sig; term = 1; }
int main(void) {
    signal(SIGTERM, on_term);
    for (int i = 0; i < 3000 && !term; i++) usleep(100000);
    if (term) usleep(600000);
    return 0;
}' > "$TMP/decoy.c"
cc -o "$TMP/decoy" "$TMP/decoy.c" || { echo "FAIL: cannot build the decoy"; exit 1; }

# Regex metacharacters and a space in the checkout path prove the escaping.
OWN="${TMP:A}/t.e+s(t) x"
OTHER="${TMP:A}/other"
SUFFIX="${TMP:A}/wrap$OWN"  # a path that ends with this checkout's path
REL="build/Tiler.app/Contents/MacOS"
for dir in "$OWN" "$OTHER" "$SUFFIX"; do
    mkdir -p "$dir/$REL"
    cp "$TMP/decoy" "$dir/$REL/Tiler"
done
cp "$TMP/decoy" "$OWN/$REL/Tiler2"

cd "$OWN" || exit 1
source "$HELPER" || { echo "FAIL: cannot source $HELPER"; exit 1; }

[[ "$TILER_BUILD_BIN" == "$OWN/$REL/Tiler" ]]
check $? "TILER_BUILD_BIN is this checkout's absolute build path"
[[ "${(j:|:)TILER_ISOLATED_ARGS}" == "-powerDebugLogging|<false/>|-gesturesEnabled|<false/>" ]]
check $? "TILER_ISOLATED_ARGS turns the debug log and gestures off"

"$TILER_BUILD_BIN" &
OWN_BARE=$!
"$TILER_BUILD_BIN" "${TILER_ISOLATED_ARGS[@]}" --show-guide &
OWN_ARGS=$!
"$OTHER/$REL/Tiler" &
OTHER_ABS=$!
(cd "$OTHER" && exec "$REL/Tiler") &
OTHER_REL=$!
"$OWN/$REL/Tiler2" &
LONGER=$!
"$SUFFIX/$REL/Tiler" &
ENDS_WITH=$!
PIDS=($OWN_BARE $OWN_ARGS $OTHER_ABS $OTHER_REL $LONGER $ENDS_WITH)
sleep 0.3

tiler_build_running
check $? "tiler_build_running sees this checkout's build"

tiler_stop_build
check $? "tiler_stop_build returns 0"
! alive $OWN_BARE
check $? "own copy (no arguments) stopped"
! alive $OWN_ARGS
check $? "own copy (with arguments) stopped"
alive $OTHER_ABS
check $? "another checkout's build (absolute launch) left alone"
alive $OTHER_REL
check $? "a relative launch from another checkout left alone"
alive $LONGER
check $? "a longer executable path (Tiler2) left alone"
alive $ENDS_WITH
check $? "a path that ends with this checkout's path left alone"

tiler_build_running
[[ $? == 1 ]]
check $? "tiler_build_running is false with only other copies running"

OUT=$(zsh -c '
    set -euo pipefail
    cd "$1" && source "$2"
    tiler_sleep_disabled() { return 1; }
    tiler_stop_build
    tiler_require_sleep_enabled
    echo survived' guard "$OWN" "$HELPER" 2>&1)
[[ "$OUT" == "survived" ]]
check $? "stop with nothing running and an enabled-sleep guard survive set -e"

(tiler_sleep_disabled() { return 0; }; tiler_require_sleep_enabled; exit 0) 2> "$TMP/err" > /dev/null
[[ $? == 2 ]]
check $? "tiler_require_sleep_enabled exits 2 while sleep is disabled"
[[ "$(<"$TMP/err")" == REFUSED:* ]]
check $? "the refusal is one REFUSED: line on stderr"

(tiler_sleep_disabled() { return 1; }; tiler_require_sleep_enabled)
check $? "tiler_require_sleep_enabled returns 0 while sleep is enabled"

pmset -g | grep -Eq 'SleepDisabled[[:space:]]+1'
EXPECTED=$?
tiler_sleep_disabled
[[ $? == "$EXPECTED" ]]
check $? "tiler_sleep_disabled agrees with pmset -g on this machine"

echo ""
if [[ "$FAIL" == "0" ]]; then echo "BUILD-COPY SELF-TEST: ALL PASS"; else echo "BUILD-COPY SELF-TEST: FAILURES PRESENT"; fi
exit $FAIL
