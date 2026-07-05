#!/usr/bin/env bash
# Builds a standalone KeyOpen.app you can launch from Finder (no terminal needed).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building release binary…"
swift build -c release

APP="KeyOpen.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/KeyOpen "$APP/Contents/MacOS/KeyOpen"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>KeyOpen</string>
    <key>CFBundleDisplayName</key><string>KeyOpen</string>
    <key>CFBundleIdentifier</key><string>com.hjl1045.KeyOpen</string>
    <key>CFBundleExecutable</key><string>KeyOpen</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc code-sign so the Accessibility permission sticks across rebuilds
# (an unsigned binary gets a new identity each build and re-prompts).
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built ./$APP"
echo "Launch it with:  open $APP     (or double-click it in Finder)"
echo "To install:      mv $APP /Applications/"
