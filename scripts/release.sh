#!/usr/bin/env bash
# Builds the direct-download KeyOpen.app, signs it with the Developer ID,
# notarizes and staples it, and zips it to dist/KeyOpen-<version>.zip.
#
#   ./scripts/release.sh
#
# Needs the Developer ID Application cert in the keychain and a notarytool
# keychain profile (default: localflow-notary, the same Apple team; override
# with NOTARY_PROFILE). Set up a new profile with:
#   xcrun notarytool store-credentials <name> --apple-id … --team-id V8PU3S5GHV
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${DEVELOPER_ID:-Developer ID Application: The Autonomes Technologies LLC (V8PU3S5GHV)}"
PROFILE="${NOTARY_PROFILE:-localflow-notary}"

./scripts/package.sh

# Re-sign for distribution: the hardened runtime and a secure timestamp are
# what notarization requires; package.sh's development signature has neither.
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" KeyOpen.app
codesign --verify --strict --verbose=2 KeyOpen.app

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' KeyOpen.app/Contents/Info.plist)"
mkdir -p dist
ZIP="dist/KeyOpen-$VERSION.zip"
rm -f "$ZIP"

# Notarize a zip of the app, then staple the ticket to the app itself so it
# opens offline, then zip the stapled app for real. ditto preserves the bundle
# structure and metadata (plain `zip` can corrupt an .app).
ditto -c -k --keepParent KeyOpen.app "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple KeyOpen.app
rm -f "$ZIP"
ditto -c -k --keepParent KeyOpen.app "$ZIP"

# What a downloader's Gatekeeper will say.
spctl --assess --type execute --verbose=2 KeyOpen.app

echo "Wrote $ZIP"
echo -n "sha256: "; shasum -a 256 "$ZIP" | awk '{print $1}'
