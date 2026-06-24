#!/usr/bin/env bash
# Build a universal Release PowerSnek.app and, when a Developer ID identity is
# provided via APPLE_DEVELOPER_IDENTITY, sign it with Hardened Runtime.
# Output: dist/PowerSnek.app
set -euo pipefail
cd "$(dirname "$0")/../.."

DERIVED="build"
DIST="dist"
APP_SRC="$DERIVED/Build/Products/Release/PowerSnek.app"
ENTITLEMENTS="Sources/PowerSnek/Resources/PowerSnek.entitlements"

command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen is required (brew install xcodegen)"; exit 1; }
xcodegen generate

echo "==> Building universal Release app (arm64 + x86_64)"
xcodebuild build \
  -project PowerSnek.xcodeproj \
  -scheme PowerSnek \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO

rm -rf "$DIST"; mkdir -p "$DIST"
cp -R "$APP_SRC" "$DIST/PowerSnek.app"
APP="$DIST/PowerSnek.app"

if [[ -n "${APPLE_DEVELOPER_IDENTITY:-}" ]]; then
  echo "==> Signing with: $APPLE_DEVELOPER_IDENTITY"
  sign() { codesign --force --options runtime --timestamp --sign "$APPLE_DEVELOPER_IDENTITY" "$@"; }

  # Sign INSIDE-OUT. On the Xcode 26 toolchain the linker leaves an ad-hoc
  # signature on every Mach-O; `codesign` on a bundle will NOT re-sign through
  # that (it errors "code object is not signed at all"), so each inner binary
  # must be signed before its bundle. A glob loop — not `find | while` — keeps
  # any failure visible under `set -e` instead of swallowing it in a subshell.
  shopt -s nullglob
  for fw in "$APP/Contents/Frameworks"/*.framework; do
    name="$(basename "$fw" .framework)"
    echo "  - signing framework: $name"
    sign "$fw/Versions/A/$name"   # inner binary first
    sign "$fw/Versions/A"         # then the version bundle
  done
  shopt -u nullglob

  app_bin="$APP/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$APP/Contents/Info.plist")"
  echo "  - signing app binary: $(basename "$app_bin")"
  sign "$app_bin"
  echo "  - signing app bundle"
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APPLE_DEVELOPER_IDENTITY" "$APP"

  echo "==> Verifying signature"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  echo "==> APPLE_DEVELOPER_IDENTITY not set; leaving the app unsigned."
fi

echo "==> App ready at $APP"
