#!/usr/bin/env bash
# Builds the Mac App Store edition of KeyOpen as a signed installer package,
# ready to upload with Transporter.
#
#   ./scripts/appstore.sh             signed .pkg in dist/appstore/
#   ./scripts/appstore.sh --dry-run   same bundle, ad-hoc signed, unsigned .pkg:
#                                     checks the structure before certs exist
#
# A real build needs, from the App Store Connect setup (THE-280):
#   - the "Apple Distribution" and "3rd Party Mac Developer Installer" (Mac
#     Installer Distribution) certificates in the keychain
#   - APPSTORE_PROFILE: path to the Mac App Store provisioning profile for
#     APPSTORE_BUNDLE_ID
#
# The edition is the same binary as the direct download. It notices the
# sandbox at runtime, asks once for read access to ~/Library, skips menu
# reading and the update check, and takes tips through in-app purchase.
set -euo pipefail
cd "$(dirname "$0")/.."

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

TEAM_ID="V8PU3S5GHV"
BUNDLE_ID="${APPSTORE_BUNDLE_ID:-com.theautonomes.keyopen}"
APP_ID="${APPSTORE_APP_IDENTITY:-Apple Distribution: The Autonomes Technologies LLC ($TEAM_ID)}"
PKG_ID="${APPSTORE_INSTALLER_IDENTITY:-3rd Party Mac Developer Installer: The Autonomes Technologies LLC ($TEAM_ID)}"
PROFILE="${APPSTORE_PROFILE:-}"

if [ "$DRY_RUN" = 0 ] && [ ! -f "$PROFILE" ]; then
    echo "Set APPSTORE_PROFILE to the Mac App Store provisioning profile (.provisionprofile)." >&2
    exit 1
fi

# The sandboxed bundle: icon, Info.plist, entitlements. package.sh is the one
# place that knows how to lay out the app.
./scripts/package.sh --sandbox
OUT="dist/appstore"
APP="$OUT/KeyOpen.app"
rm -rf "$OUT" && mkdir -p "$OUT"
ditto "KeyOpen Sandbox.app" "$APP"
rm -rf "KeyOpen Sandbox.app"

# The App Store identity, not the local test one. Plus the two keys App Store
# Connect asks about on every upload: the category, and that KeyOpen uses no
# encryption beyond what macOS provides.
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName KeyOpen" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.productivity" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"

# Apple silicon and Intel in one binary: the store serves one build to every
# Mac that meets LSMinimumSystemVersion.
swift build -c release --arch arm64 --arch x86_64 2>&1 | grep -v "x86_64 architecture is deprecated" || true
cp .build/out/Products/Release/KeyOpen "$APP/Contents/MacOS/KeyOpen"

# The sandbox entitlements plus the two that tie the bundle to its
# provisioning profile.
ENT="$OUT/KeyOpen.entitlements"
cp scripts/KeyOpen-AppStore.entitlements "$ENT"
/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" "$ENT"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$ENT"

PKG="$OUT/KeyOpen-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST").pkg"
if [ "$DRY_RUN" = 1 ]; then
    codesign --force --sign - --entitlements "$ENT" "$APP"
    productbuild --component "$APP" /Applications "$PKG"
else
    cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
    codesign --force --timestamp --sign "$APP_ID" --entitlements "$ENT" "$APP"
    productbuild --component "$APP" /Applications --sign "$PKG_ID" "$PKG"
fi

codesign --verify --strict --verbose=2 "$APP"
echo "Bundle id:    $BUNDLE_ID"
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/KeyOpen")"
echo "Wrote $PKG"
[ "$DRY_RUN" = 1 ] && echo "(dry run: ad-hoc signed, not uploadable)"
[ "$DRY_RUN" = 0 ] && echo "Upload it with Transporter, or: xcrun altool --upload-package \"$PKG\" …"
exit 0
