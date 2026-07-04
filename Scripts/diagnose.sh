#!/bin/zsh
# CLI mirror of Tiler's in-app conflict diagnostics (app-shell spec).
# Read-only: reports system trackpad settings that compete with 3-finger gestures.
set -uo pipefail

read_key() {
    defaults read "$1" "$2" 2>/dev/null || echo "absent"
}

echo "Tiler conflict diagnostics"
echo "=========================="
conflicts=0

for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
    drag=$(read_key "$domain" TrackpadThreeFingerDrag)
    horiz=$(read_key "$domain" TrackpadThreeFingerHorizSwipeGesture)
    vert=$(read_key "$domain" TrackpadThreeFingerVertSwipeGesture)
    echo ""
    echo "[$domain]"
    echo "  TrackpadThreeFingerDrag              = $drag"
    echo "  TrackpadThreeFingerHorizSwipeGesture = $horiz"
    echo "  TrackpadThreeFingerVertSwipeGesture  = $vert"
    [[ "$drag" == "1" ]] && { echo "  ⚠ Three Finger Drag is ON (Accessibility → Pointer Control → Trackpad Options)"; conflicts=$((conflicts+1)); }
    [[ "$horiz" != "0" && "$horiz" != "absent" ]] && { echo "  ⚠ System 3-finger horizontal swipes are ON (Trackpad → More Gestures)"; conflicts=$((conflicts+1)); }
    [[ "$vert" != "0" && "$vert" != "absent" ]] && { echo "  ⚠ Mission Control/App Exposé 3-finger swipes are ON (Trackpad → More Gestures)"; conflicts=$((conflicts+1)); }
done

echo ""
if (( conflicts == 0 )); then
    echo "OK: no conflicting system three-finger gestures detected."
else
    echo "$conflicts conflict(s) found. Gesture acceptance requires them disabled."
fi
