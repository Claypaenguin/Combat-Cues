#!/usr/bin/env bash
# Prints the CHANGELOG.md section for a version, for use as GitHub release notes.
# Usage: scripts/release-notes.sh <version>   (a leading "v" is ignored)
# Exits with an error if CHANGELOG.md has no section for that version.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:?usage: scripts/release-notes.sh <version>}"
VERSION="${VERSION#v}"

awk -v header="## [${VERSION}]" '
    /^## \[/ { if (found) exit; if (index($0, header) == 1) { found = 1; next } }
    found && !started && /^[[:space:]]*$/ { next }
    found { started = 1; print }
    END { if (!found) { print "CHANGELOG.md has no section for " header > "/dev/stderr"; exit 1 } }
' CHANGELOG.md
