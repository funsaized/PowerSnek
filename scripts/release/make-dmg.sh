#!/usr/bin/env bash
# Package dist/PowerSnek.app into a compressed DMG with an /Applications symlink.
# Usage: make-dmg.sh <version>
set -euo pipefail
cd "$(dirname "$0")/../.."

VERSION="${1:?usage: make-dmg.sh <version>}"
APP="dist/PowerSnek.app"
[[ -d "$APP" ]] || { echo "missing $APP — run build-and-sign.sh first"; exit 1; }

DMG="dist/PowerSnek-$VERSION.dmg"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/PowerSnek.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "PowerSnek" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "==> DMG: $DMG"
