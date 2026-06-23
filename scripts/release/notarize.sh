#!/usr/bin/env bash
# Notarize and staple a .dmg (or .app) with notarytool.
# Credentials (either set works):
#   - API key:  APPLE_NOTARYTOOL_API_KEY_ID, APPLE_NOTARYTOOL_API_ISSUER_ID,
#               APPLE_NOTARYTOOL_API_KEY (the raw .p8 contents)
#   - Keychain: NOTARY_KEYCHAIN_PROFILE (a profile saved via
#               `xcrun notarytool store-credentials`)
# If neither is present, notarization is skipped (exit 0) so unsigned builds
# still produce an artifact.
set -euo pipefail

TARGET="${1:?usage: notarize.sh <path-to-dmg-or-app>}"
[[ -e "$TARGET" ]] || { echo "missing $TARGET"; exit 1; }

if [[ -n "${APPLE_NOTARYTOOL_API_KEY:-}" ]]; then
  KEYFILE="$(mktemp -t notary).p8"
  trap 'rm -f "$KEYFILE"' EXIT
  printf '%s' "$APPLE_NOTARYTOOL_API_KEY" > "$KEYFILE"
  echo "==> Submitting $TARGET to notarytool (API key)"
  xcrun notarytool submit "$TARGET" \
    --key "$KEYFILE" \
    --key-id "${APPLE_NOTARYTOOL_API_KEY_ID:?}" \
    --issuer "${APPLE_NOTARYTOOL_API_ISSUER_ID:?}" \
    --wait
elif [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  echo "==> Submitting $TARGET to notarytool (keychain profile)"
  xcrun notarytool submit "$TARGET" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
else
  echo "==> Notarization skipped: no notarytool credentials present."
  exit 0
fi

echo "==> Stapling $TARGET"
xcrun stapler staple "$TARGET"
echo "==> Notarized and stapled $TARGET"
