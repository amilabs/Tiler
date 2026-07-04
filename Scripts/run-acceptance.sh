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

# True CPU utilization: cputime delta over a wall interval (ps %cpu is a lifetime
# average on macOS and stays polluted by the launch spike for a long time).
cputime_s() {
    ps -o cputime= -p "$1" | tr -d ' ' | awk -F: '{ if (NF==3) print $1*3600+$2*60+$3; else print $1*60+$2 }'
}

measure_util() { # $1 = pid, $2 = seconds; echoes percent, returns 0 if < 1%
    local c1 c2 pct
    c1=$(cputime_s "$1"); [[ -z "$c1" ]] && { echo "gone"; return 1; }
    sleep "$2"
    c2=$(cputime_s "$1"); [[ -z "$c2" ]] && { echo "gone"; return 1; }
    pct=$(awk -v a="$c1" -v b="$c2" -v t="$2" 'BEGIN{printf "%.2f", (b-a)/t*100}')
    echo "$pct"
    awk -v p="$pct" 'BEGIN{ exit (p < 1.0) ? 0 : 1 }'
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

echo "== 2. Idle CPU over ${IDLE_SECONDS}s (true utilization, budget < 1%)"
sleep 4
PCT=$(measure_util "$PID" "$IDLE_SECONDS"); CPU_OK=$?
echo "  idle utilization: ${PCT}%"
say_result $CPU_OK "idle CPU < 1% (measured ${PCT}%)"

echo "== 3. idle CPU with the UI window OPEN and after close"
pkill -f "$BIN" 2>/dev/null; sleep 0.5
"$BIN" --show-guide > /dev/null 2>&1 &
PID=$!
sleep 5
PCT=$(measure_util "$PID" 10); OPEN_OK=$?
echo "  open-window utilization: ${PCT}%"
say_result $OPEN_OK "idle CPU < 1% with the window open"
pkill -f "$BIN" 2>/dev/null; sleep 0.5
"$BIN" --exercise-ui > /dev/null 2>&1 &
PID=$!
sleep 8   # window opens, closes at 2 s, settle
PCT=$(measure_util "$PID" 10); UI_OK=$?
echo "  post-UI utilization: ${PCT}%"
say_result $UI_OK "idle CPU < 1% after opening and closing the UI"
kill "$PID" 2>/dev/null; sleep 0.5

echo "== 4. kill -9 resilience"
"$BIN" > /dev/null 2>&1 &
PID=$!
sleep 2
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
