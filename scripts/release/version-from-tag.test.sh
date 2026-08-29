#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

[[ "$(scripts/release/version-from-tag.sh v0.2.1)" == "0.2.1" ]]
for tag in "" v1 v1.2 1.2.3 v01.2.3 v1.02.3 v1.2.03 v1.2.3-rc.1; do
  if scripts/release/version-from-tag.sh "$tag" >/dev/null 2>&1; then
    echo "unexpected valid release tag: $tag" >&2
    exit 1
  fi
done
