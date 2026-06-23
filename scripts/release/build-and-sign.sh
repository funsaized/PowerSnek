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
  # Sign embedded frameworks first (inside-out), then the app bundle.
  if [[ -d "$APP/Contents/Frameworks" ]]; then
    find "$APP/Contents/Frameworks" -maxdepth 1 -name "*.framework" -print0 \
      | while IFS= read -r -d '' fw; do
          codesign --force --options runtime --timestamp \
            --sign "$APPLE_DEVELOPER_IDENTITY" "$fw"
        done
  fi
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APPLE_DEVELOPER_IDENTITY" "$APP"
  echo "==> Verifying signature"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  echo "==> APPLE_DEVELOPER_IDENTITY not set; leaving the app unsigned."
fi

echo "==> App ready at $APP"
