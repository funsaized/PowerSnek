# PowerSnek release pipeline

`.github/workflows/release.yml` builds a universal `PowerSnek.app`, signs it with
Developer ID + Hardened Runtime, packages a DMG, notarizes and staples it,
checksums it, and publishes a **draft** GitHub Release. It runs on `v*` tags or
via **Run workflow** (workflow_dispatch).

Signing and notarization are **secret-gated** (like the build): if the secrets
are absent the workflow still produces an **unsigned** DMG so the pipeline is
never red just because credentials aren't configured yet.

## Required repository secrets

Add these under **Settings → Secrets and variables → Actions**.

### Signing (Developer ID Application)
| Secret | What it is |
| --- | --- |
| `APPLE_DEVELOPER_ID_CERT` | Base64 of your exported `Developer ID Application` certificate `.p12` (`base64 -i cert.p12 \| pbcopy`) |
| `APPLE_DEVELOPER_ID_CERT_PASSWORD` | The password you set when exporting the `.p12` |
| `APPLE_DEVELOPER_IDENTITY` | The identity string, e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_KEYCHAIN_PASSWORD` | Any throwaway password for the temporary CI keychain |

### Notarization (notarytool API key)
| Secret | What it is |
| --- | --- |
| `APPLE_NOTARYTOOL_API_KEY_ID` | Key ID of an App Store Connect API key (Keys tab) |
| `APPLE_NOTARYTOOL_API_ISSUER_ID` | Issuer ID from the same page |
| `APPLE_NOTARYTOOL_API_KEY` | The raw contents of the downloaded `AuthKey_XXXX.p8` |

## Running locally

```bash
# Unsigned (no secrets needed) — produces dist/PowerSnek-<version>.dmg
scripts/release/build-and-sign.sh
scripts/release/make-dmg.sh 0.1.0

# Signed + notarized locally:
export APPLE_DEVELOPER_IDENTITY="Developer ID Application: Your Name (TEAMID)"
scripts/release/build-and-sign.sh                       # signs with the identity in your keychain
scripts/release/make-dmg.sh 0.1.0
# Either store a notarytool keychain profile once …
#   xcrun notarytool store-credentials PowerSnekNotary --key AuthKey_XXXX.p8 --key-id <id> --issuer <issuer>
NOTARY_KEYCHAIN_PROFILE=PowerSnekNotary scripts/release/notarize.sh dist/PowerSnek-0.1.0.dmg
```

## Scripts
- `build-and-sign.sh` — universal Release build (+ optional Developer ID signing)
- `make-dmg.sh <version>` — package `dist/PowerSnek.app` into a DMG
- `notarize.sh <path>` — notarize + staple (API key env **or** keychain profile)
- `import-cert.sh` — CI-only: import the base64 `.p12` into a temp keychain
