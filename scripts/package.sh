#!/usr/bin/env bash
# Builds a standalone KeyOpen.app you can launch from Finder (no terminal needed).
#
#   ./scripts/package.sh            the direct build (KeyOpen.app)
#   ./scripts/package.sh --sandbox  the App Store build, sandboxed, as a separate
#                                   app (KeyOpen Sandbox.app) so it can be tried
#                                   next to the installed one
set -euo pipefail
cd "$(dirname "$0")/.."

APP="KeyOpen.app"
BUNDLE_ID="com.hjl1045.KeyOpen"
DISPLAY_NAME="KeyOpen"
ENTITLEMENTS=()
if [ "${1:-}" = "--sandbox" ]; then
    APP="KeyOpen Sandbox.app"
    BUNDLE_ID="com.hjl1045.KeyOpen.sandbox"
    DISPLAY_NAME="KeyOpen Sandbox"
    ENTITLEMENTS=(--entitlements scripts/KeyOpen-AppStore.entitlements)
fi

echo "Building release binary…"
swift build -c release

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

        # The Mac App Store also wants an asset catalog (Assets.car): without
        # one, processing rejects the build with ITMS-90546 "Missing asset
        # catalog", even though altool's pre-upload validation passes. actool
        # compiles the same PNGs into Assets.car (and rewrites AppIcon.icns).
        if xcrun --find actool >/dev/null 2>&1; then
            SET="$TMP/Assets.xcassets/AppIcon.appiconset"; mkdir -p "$SET"
            cp "$ICONSET"/*.png "$SET/"
            python3 - "$SET" <<'PY'
import json, sys
images = []
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        suffix = "" if scale == 1 else "@2x"
        images.append({"idiom": "mac", "size": f"{size}x{size}", "scale": f"{scale}x",
                       "filename": f"icon_{size}x{size}{suffix}.png"})
json.dump({"images": images, "info": {"version": 1, "author": "xcode"}},
          open(f"{sys.argv[1]}/Contents.json", "w"), indent=2)
json.dump({"info": {"version": 1, "author": "xcode"}},
          open(f"{sys.argv[1]}/../Contents.json", "w"), indent=2)
PY
            xcrun actool --compile "$APP/Contents/Resources" --platform macosx \
                --minimum-deployment-target 13.0 --app-icon AppIcon \
                --output-partial-info-plist "$TMP/actool-info.plist" \
                "$TMP/Assets.xcassets" >/dev/null
            echo "Icon embedded (with asset catalog)."
        else
            echo "Icon embedded (no actool: no asset catalog; the App Store will reject this build)."
        fi
    else
        echo "Icon generation skipped (render failed)."
    fi
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>KeyOpen</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>KeyOpen</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.2.3</string>
    <key>CFBundleVersion</key><string>6</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Sign with a STABLE identity if one is available, so the Accessibility grant
# persists across rebuilds. Preference: $CODESIGN_IDENTITY, else the first valid
# code-signing identity (an Xcode "Apple Development" cert works), else ad-hoc.
SIGN_ID="${CODESIGN_IDENTITY:-}"
if [ -z "$SIGN_ID" ]; then
    SIGN_ID="$(security find-identity -p codesigning -v 2>/dev/null \
        | awk 'match($0, /[0-9A-F]{40}/) { print substr($0, RSTART, 40); exit }')"
fi
if [ -n "$SIGN_ID" ] && codesign --force --deep --sign "$SIGN_ID" ${ENTITLEMENTS[@]+"${ENTITLEMENTS[@]}"} "$APP" >/dev/null 2>&1; then
    echo "Signed with identity $SIGN_ID (stable — Accessibility grant will persist)."
else
    codesign --force --deep --sign - ${ENTITLEMENTS[@]+"${ENTITLEMENTS[@]}"} "$APP" >/dev/null 2>&1 || true
    echo "Ad-hoc signed (no code-signing identity found). The Accessibility grant"
    echo "will reset on each rebuild — run ./scripts/setup-signing.sh to get a"
    echo "stable identity."
fi

echo "Built ./$APP"
echo "Launch it with:  open \"$APP\"     (or double-click it in Finder)"
echo "To install:      mv \"$APP\" /Applications/"
