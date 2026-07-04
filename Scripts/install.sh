#!/bin/zsh
# Install Tiler.app into ~/Applications and prepare it for a persistent
# Accessibility grant.
#
# Why not run from build/ or /Users/Shared:
#  - make-app.sh does `rm -rf build/Tiler.app` on every build, which replaces the
#    exact bundle the user granted and drops the TCC grant ("it got deleted").
#  - /Users/Shared has a world-writable root (drwxrwxrwt); TCC is reluctant to
#    persist Accessibility grants for apps under an insecure/other-writable path.
# ~/Applications is user-owned, secure, and stable across dev rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="WindowGestures Local Dev"
DEST="$HOME/Applications/Tiler.app"

Scripts/make-app.sh > /dev/null
pkill -f "Tiler.app/Contents/MacOS/Tiler" 2>/dev/null || true
sleep 1

rm -rf "$DEST"
mkdir -p "$HOME/Applications"
cp -R build/Tiler.app "$DEST"
xattr -cr "$DEST" 2>/dev/null || true
codesign --force --sign "$IDENTITY" "$DEST"

echo "Installed: $DEST"
echo ""
echo "Grant Accessibility (one time):"
echo "  1. Open the app:      open \"$DEST\""
echo "  2. On the prompt, click \"Open System Settings\" (or open"
echo "     System Settings → Privacy & Security → Accessibility)."
echo "  3. Enable the Tiler toggle."
echo ""
echo "The grant persists across future 'swift build' / make-app.sh runs because"
echo "this bundle is separate from build/. Re-run this script only to ship a new"
echo "version into ~/Applications (you'll re-confirm the toggle once after that)."
