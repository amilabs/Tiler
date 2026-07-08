#!/bin/zsh
# Power acceptance: Prevent Sleep assertion lifecycle incl. crash safety.
# No Accessibility, no admin needed (unlike run-acceptance.sh, which is AX-gated).
set -u
BIN=.build/debug/Tiler
FAIL=0
note() { print -- "== $1" }
swift build >/dev/null || exit 1

note "start 10m session"
$BIN --power-start 10m & PID=$!
sleep 2
pmset -g assertions | grep -q "Tiler Keep Awake (idle)" || { print "FAIL: assertion missing"; FAIL=1; }

note "clean stop releases (SIGTERM)"
kill -TERM $PID; sleep 2
pmset -g assertions | grep -q "Tiler Keep Awake" && { print "FAIL: assertion survived TERM"; FAIL=1; }

note "kill -9 crash safety"
$BIN --power-start 10m & PID=$!
sleep 2
kill -9 $PID; sleep 2
pmset -g assertions | grep -q "Tiler Keep Awake" && { print "FAIL: assertion survived SIGKILL"; FAIL=1; }

[ $FAIL -eq 0 ] && print "POWER ACCEPTANCE: ALL PASS"
exit $FAIL
