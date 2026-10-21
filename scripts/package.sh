#!/usr/bin/env bash
# Builds dist/CombatCues-<version>.zip with the CombatCues folder at the top level.
# Usage: scripts/package.sh [version]   (defaults to the version in the .toc)
set -euo pipefail

cd "$(dirname "$0")/.."
TOC="CombatCues/CombatCues.toc"
VERSION="${1:-$(sed -n 's/^## Version: *//p' "$TOC" | tr -d '\r')}"
VERSION="${VERSION#v}"

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

cp -R CombatCues "$BUILD/"
sed -i.bak "s/^## Version:.*/## Version: ${VERSION}/" "$BUILD/$TOC" && rm "$BUILD/$TOC.bak"
find "$BUILD" -name '.DS_Store' -delete

mkdir -p dist
OUT="$PWD/dist/CombatCues-${VERSION}.zip"
rm -f "$OUT"
(cd "$BUILD" && zip -rq "$OUT" CombatCues)
echo "$OUT"
