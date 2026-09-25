// The release the website offers. Bump alongside MARKETING_VERSION in
// project.yml when a release is published.
//
// Releases from v0.3.0 on also carry a version-less `PowerSnek.dmg` alias
// (see .github/workflows/release.yml); once one is the latest release,
// DMG_URL can become `${REPO_URL}/releases/latest/download/PowerSnek.dmg`
// and stop needing a bump.
export const LATEST_VERSION = "0.3.0";
export const DMG_SIZE_MB = 1;

export const REPO_URL = "https://github.com/funsaized/PowerSnek";
export const RELEASES_URL = `${REPO_URL}/releases`;
export const DMG_URL = `${RELEASES_URL}/download/v${LATEST_VERSION}/PowerSnek-${LATEST_VERSION}.dmg`;
