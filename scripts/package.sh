#!/usr/bin/env bash
# Builds a standalone KeyOpen.app you can launch from Finder (no terminal needed).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building release binary…"
swift build -c release

APP="KeyOpen.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KeyOpen "$APP/Contents/MacOS/KeyOpen"

# --- App icon: render 1024 PNG → .iconset → AppIcon.icns ---
if command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
    TMP="$(mktemp -d)"
    ICON_PNG="$TMP/AppIcon-1024.png"
    if swift scripts/make-icon.swift "$ICON_PNG" >/dev/null 2>&1; then
        ICONSET="$TMP/AppIcon.iconset"; mkdir -p "$ICONSET"
        gen() { sips -z "$1" "$1" "$ICON_PNG" --out "$ICONSET/$2" >/dev/null; }
        gen 16   icon_16x16.png;    gen 32   icon_16x16@2x.png
        gen 32   icon_32x32.png;    gen 64   icon_32x32@2x.png
        gen 128  icon_128x128.png;  gen 256  icon_128x128@2x.png
        gen 256  icon_256x256.png;  gen 512  icon_256x256@2x.png
        gen 512  icon_512x512.png;  gen 1024 icon_512x512@2x.png
        iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
        echo "Icon embedded."
    else
        echo "Icon generation skipped (render failed)."
    fi
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>KeyOpen</string>
    <key>CFBundleDisplayName</key><string>KeyOpen</string>
    <key>CFBundleIdentifier</key><string>com.hjl1045.KeyOpen</string>
    <key>CFBundleExecutable</key><string>KeyOpen</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
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
