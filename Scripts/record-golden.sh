#!/bin/zsh
# USER GATE #3 helper: records a golden touch trace (tasks.md 8.1).
# Launches Tiler with --record-touches and walks the owner through the gesture set.
# The resulting JSONL becomes frozen test fixtures.
# Isolated from the owner's Tiler (fix-script-launch-isolation): the recording copy is
# this checkout's build with debug logging and gestures off — it records every frame
# but moves no window (the installed copy, if running, acts as usual and is never
# touched) — and is stopped by its exact path only. Refuses (exit 2) while sleep is
# disabled.
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/lib/build-copy.zsh
tiler_require_sleep_enabled

OUT="${1:-Tests/TilerCoreTests/Fixtures/golden-$(date +%Y%m%d-%H%M%S).jsonl}"
mkdir -p "$(dirname "$OUT")"

Scripts/make-app.sh > /dev/null
tiler_stop_build

"$TILER_BUILD_BIN" "${TILER_ISOLATED_ARGS[@]}" --record-touches "$OUT" > /dev/null 2>&1 &
PID=$!
sleep 2
echo "Recording to: $OUT"
echo "This copy only records (gestures off): windows move only if your installed Tiler is running."
echo "Perform each step ON THE TRACKPAD, press Enter here after each one."
echo ""
steps=(
  "2-finger VERTICAL scroll in Safari or Finder (up and down, include momentum flick)"
  "2-finger HORIZONTAL scroll (e.g. wide page/timeline)"
  "2-finger DIAGONAL scroll"
  "2-finger scroll, then ADD a third finger mid-scroll and keep moving"
  "2 fingers down, briefly TAP a third finger (2→3→2), continue scrolling"
  "Rest your PALM + scroll with two fingers"
  "3-finger swipe at ~30° DIAGONAL (should do nothing)"
  "Valid 3-finger swipe LEFT ×5 (distinct swipes, lift between)"
  "Valid 3-finger swipe RIGHT ×5"
  "Valid 3-finger swipe UP ×5"
  "3-finger swipe left/right with Cmd HELD ×3 each"
  "Slow lazy 3-finger drift (should do nothing)"
)
i=1
for step in "${steps[@]}"; do
    printf "[%2d/%d] %s\n" "$i" "${#steps[@]}" "$step"
    read -r "?      done? [Enter] "
    i=$((i+1))
done
kill "$PID" 2>/dev/null
sleep 0.5
LINES=$(wc -l < "$OUT" | tr -d ' ')
echo ""
echo "Recorded $LINES frames to $OUT — commit this file and let Claude freeze fixtures."
