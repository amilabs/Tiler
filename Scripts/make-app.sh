#!/bin/zsh
# Assemble and codesign Tiler.app from the SwiftPM release build.
# Signing uses the stable local identity so TCC grants survive rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="WindowGestures Local Dev"
VERSION="0.1.0"
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
    <key>CFBundleIdentifier</key><string>pro.amilabs.tiler</string>
    <key>CFBundleName</key><string>Tiler</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign "$IDENTITY" "$APP"
echo "Built and signed: $APP"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Authority|Signature' || true
