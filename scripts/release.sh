#!/usr/bin/env bash
# Builds KeyOpen.app and zips it for distribution (GitHub Release / Homebrew cask).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/package.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' KeyOpen.app/Contents/Info.plist)"
mkdir -p dist
ZIP="dist/KeyOpen-$VERSION.zip"
rm -f "$ZIP"
# ditto preserves the bundle structure/metadata (plain `zip` can corrupt .app).
ditto -c -k --keepParent KeyOpen.app "$ZIP"

echo "Wrote $ZIP"
echo -n "sha256: "; shasum -a 256 "$ZIP" | awk '{print $1}'
