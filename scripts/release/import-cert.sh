#!/usr/bin/env bash
# CI only: import a base64-encoded "Developer ID Application" .p12 into a
# dedicated temporary keychain so codesign can find the identity.
# Required env:
#   APPLE_DEVELOPER_ID_CERT          base64 of the exported .p12
#   APPLE_DEVELOPER_ID_CERT_PASSWORD the .p12 export password
#   APPLE_KEYCHAIN_PASSWORD          an arbitrary password for the temp keychain
set -euo pipefail

: "${APPLE_DEVELOPER_ID_CERT:?APPLE_DEVELOPER_ID_CERT is required}"
: "${APPLE_DEVELOPER_ID_CERT_PASSWORD:?APPLE_DEVELOPER_ID_CERT_PASSWORD is required}"
: "${APPLE_KEYCHAIN_PASSWORD:?APPLE_KEYCHAIN_PASSWORD is required}"

KEYCHAIN="${RUNNER_TEMP:-/tmp}/powersnek-signing.keychain-db"
CERT="$(mktemp -t devid).p12"
trap 'rm -f "$CERT"' EXIT

printf '%s' "$APPLE_DEVELOPER_ID_CERT" | base64 --decode > "$CERT"

security create-keychain -p "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$CERT" -k "$KEYCHAIN" \
  -P "$APPLE_DEVELOPER_ID_CERT_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -k "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
# Make the temp keychain searchable alongside the existing ones.
security list-keychains -d user -s "$KEYCHAIN" \
  $(security list-keychains -d user | sed 's/"//g')

echo "==> Imported Developer ID certificate into $KEYCHAIN"
security find-identity -v -p codesigning "$KEYCHAIN"
