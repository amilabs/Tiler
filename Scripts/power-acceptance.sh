#!/bin/zsh
# Power acceptance: Prevent Sleep assertion lifecycle incl. crash safety.
# No Accessibility, no admin needed (unlike run-acceptance.sh, which is AX-gated).
# Checks are keyed to the spawned process's own PID, so this is safe to run while
# a real Tiler session is active in the menu bar (its assertion is a different pid).
set -u
BIN=.build/debug/Tiler
FAIL=0
note() { print -- "== $1" }
swift build >/dev/null || exit 1

# Does the given pid hold a Tiler assertion right now?
held() { pmset -g assertions | grep -q "pid $1(Tiler)"; }

note "start 10m session"
$BIN --power-start 10m & PID=$!
sleep 2
held $PID || { print "FAIL: assertion missing for pid $PID"; FAIL=1; }

note "clean stop releases (SIGTERM)"
kill -TERM $PID; sleep 2
held $PID && { print "FAIL: pid $PID assertion survived TERM"; FAIL=1; }

note "kill -9 crash safety"
$BIN --power-start 10m & PID=$!
sleep 2
kill -9 $PID; sleep 2
held $PID && { print "FAIL: pid $PID assertion survived SIGKILL"; FAIL=1; }

[ $FAIL -eq 0 ] && print "POWER ACCEPTANCE: ALL PASS"
exit $FAIL
