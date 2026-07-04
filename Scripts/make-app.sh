#!/bin/zsh
# Assemble and codesign Tiler.app from the SwiftPM release build.
#
# Signing/identity rules (hard-won, see README "Permissions & TCC" + tasks.md):
#  - Identity MUST be an Apple-issued one (Apple Development). Self-signed certs —
#    even trusted in the System keychain — never get an Accessibility row on
#    macOS 26 (tccd shows the prompt but silently refuses to persist the entry).
#  - Bundle id is pro.amilabs.tilerx, NOT ...tiler: the original id's TCC client
#    record got wedged on the dev machine (prompt shown, row never created, survives
#    reboot). Fresh id enrolled instantly. Keep this id or the owner re-grants.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="Apple Development: alexnsk@gmail.com (PHYV972T38)"
BUNDLE_ID="pro.amilabs.tilerx"
VERSION="0.2.0"
BUILD_DATE="$(date -u +"%Y-%m-%d %H:%M UTC")"
APP="build/Tiler.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Tiler "$APP/Contents/MacOS/Tiler"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Tiler</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>Tiler</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>TilerBuildDate</key><string>${BUILD_DATE}</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --options runtime --sign "$IDENTITY" "$APP"
echo "Built and signed: $APP"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Authority|Signature' || true
