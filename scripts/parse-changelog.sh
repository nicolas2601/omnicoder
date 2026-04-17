#!/usr/bin/env bash
# parse-changelog.sh
# ---------------------------------------------------------------------------
# Extract the changelog entry for a given version from a Keep-a-Changelog
# style CHANGELOG.md.
#
# Usage:
#   scripts/parse-changelog.sh <version> [changelog-path]
#
# Example:
#   scripts/parse-changelog.sh 4.3.0 CHANGELOG.md
#
# Behavior:
#   - Looks for a heading that starts with `## [<version>]` (bracket form,
#     Keep-a-Changelog convention) or `## <version>` (loose form).
#   - Prints everything from that heading (exclusive) up to the next `## [`
#     or `## ` heading at the same level.
#   - Exits 0 on success, 1 if the version or file is not found.
#
# Used by .github/workflows/release.yml to build the GitHub Release body.
# ---------------------------------------------------------------------------
set -euo pipefail

version="${1:-}"
changelog="${2:-CHANGELOG.md}"

if [[ -z "$version" ]]; then
    echo "usage: $0 <version> [changelog-path]" >&2
    exit 1
fi

if [[ ! -f "$changelog" ]]; then
    echo "error: changelog not found at '$changelog'" >&2
    exit 1
fi

# awk state machine:
#   - found=0: searching for the target heading
#   - found=1: inside the target section, printing lines
#   - bail when we hit the next "## " heading
awk -v ver="$version" '
    BEGIN { found = 0 }
    {
        if (found == 0) {
            # Match "## [4.3.0]" or "## [4.3.0] - 2026-04-17" or "## 4.3.0"
            if ($0 ~ "^## \\[" ver "\\]" || $0 ~ "^## " ver "([^0-9]|$)") {
                found = 1
                next
            }
        } else {
            # Stop at the next top-level version heading.
            if ($0 ~ /^## /) { exit 0 }
            print
        }
    }
    END {
        if (found == 0) { exit 2 }
    }
' "$changelog"
