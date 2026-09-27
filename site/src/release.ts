// The release the website describes (badge, details line, structured data).
// Bump alongside MARKETING_VERSION in project.yml when a release is
// published. The download link itself needs no bump: every release since
// v0.3.0 carries a version-less `PowerSnek.dmg` (see
// .github/workflows/release.yml), so DMG_URL always serves the latest one.
export const LATEST_VERSION = "0.3.0";
export const DMG_SIZE_MB = 1.3;

export const REPO_URL = "https://github.com/funsaized/PowerSnek";
export const RELEASES_URL = `${REPO_URL}/releases`;
export const DMG_URL = `${RELEASES_URL}/latest/download/PowerSnek.dmg`;
