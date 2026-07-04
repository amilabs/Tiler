#!/bin/zsh
# Self-service acceptance (app-shell + permissions specs):
#   1. launch health: hotkeys registered, touch stream started, alive without AX
#   2. idle CPU budget: every sample < 1% (IDLE_SECONDS env, default 60)
#   3. kill -9 resilience: no orphans, clean relaunch
# Exits non-zero on any failure. Run with the trackpad untouched.
set -uo pipefail
cd "$(dirname "$0")/.."

IDLE_SECONDS="${IDLE_SECONDS:-60}"
LOG="$(mktemp -t tiler-acceptance)"
BIN="build/Tiler.app/Contents/MacOS/Tiler"
FAIL=0

say_result() { # $1 = 0/1, $2 = label
    if [[ "$1" == "0" ]]; then echo "PASS: $2"; else echo "FAIL: $2"; FAIL=1; fi
}

echo "== Building signed app bundle"
Scripts/make-app.sh > /dev/null || { echo "FAIL: build"; exit 1; }

pkill -f "$BIN" 2>/dev/null; sleep 0.5

echo "== 1. Launch health"
"$BIN" > "$LOG" 2>&1 &
PID=$!
sleep 4
kill -0 "$PID" 2>/dev/null; say_result $? "process alive after launch"
grep -q "hotkeys registered" "$LOG"; say_result $? "hotkeys registered"
grep -q "touch stream started" "$LOG"; say_result $? "touch stream started"
if grep -q "accessibility missing" "$LOG"; then
    echo "INFO: running WITHOUT Accessibility — alive-without-permission path exercised"
else
    echo "INFO: Accessibility granted — permission-missing path not exercised this run"
fi

echo "== 2. Idle CPU over ${IDLE_SECONDS}s (budget: every sample < 1%)"
sleep 6   # let launch spike decay
SAMPLES=$(( IDLE_SECONDS / 5 ))
CPU_OK=0
MAX=0
for i in $(seq 1 $SAMPLES); do
    sleep 5
    CPU=$(ps -o %cpu= -p "$PID" | tr -d ' ')
    [[ -z "$CPU" ]] && { CPU_OK=1; echo "  sample $i: process gone"; break; }
    echo "  sample $i: ${CPU}%"
    awk -v c="$CPU" 'BEGIN { exit (c < 1.0) ? 0 : 1 }' || CPU_OK=1
    awk -v c="$CPU" -v m="$MAX" 'BEGIN { exit (c > m) ? 0 : 1 }' && MAX=$CPU
done
say_result $CPU_OK "idle CPU stayed < 1% (max ${MAX}%)"

echo "== 3. kill -9 resilience"
kill -9 "$PID" 2>/dev/null
sleep 1
pgrep -f "$BIN" > /dev/null && say_result 1 "no orphan after kill -9" || say_result 0 "no orphan after kill -9"
"$BIN" > "$LOG" 2>&1 &
PID=$!
sleep 3
kill -0 "$PID" 2>/dev/null; say_result $? "clean relaunch after kill -9"
grep -q "hotkeys registered" "$LOG"; say_result $? "hotkeys re-registered after relaunch"
kill "$PID" 2>/dev/null

echo ""
if [[ "$FAIL" == "0" ]]; then echo "ACCEPTANCE: ALL PASS"; else echo "ACCEPTANCE: FAILURES PRESENT"; fi
exit $FAIL
