#!/usr/bin/env bash
set -euo pipefail

TAG="${1:?usage: version-from-tag.sh <tag>}"
if [[ ! "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "release tag must be canonical SemVer (vMAJOR.MINOR.PATCH): $TAG" >&2
  exit 1
fi

printf '%s\n' "${TAG#v}"
