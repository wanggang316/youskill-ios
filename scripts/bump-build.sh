#!/bin/bash
#
# Bump build number in project.yml to date-based format.
#
# Format:
#   YYYYMMDD     — first archive of the day
#   YYYYMMDDN    — subsequent archives (N = 1, 2, 3, ...)
#
# Usage:
#   ./scripts/bump-build.sh           # bump and regenerate Xcode project
#   ./scripts/bump-build.sh --dry-run # preview without writing

set -euo pipefail

PROJECT_YML="$(cd "$(dirname "$0")/.." && pwd)/project.yml"
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [[ ! -f "$PROJECT_YML" ]]; then
  echo "error: project.yml not found at $PROJECT_YML" >&2
  exit 1
fi

TODAY=$(date +%Y%m%d)

CURRENT=$(grep 'CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | sed 's/.*CURRENT_PROJECT_VERSION: *//')

# Determine the new build number
# Extract the 8-digit date prefix from current version
DATE_PART="${CURRENT:0:8}"
if [[ "$DATE_PART" == "$TODAY" ]]; then
  SUFFIX="${CURRENT:8}"
  if [[ -z "$SUFFIX" ]]; then
    NEW_BUILD="${TODAY}1"
  else
    NEW_BUILD="${TODAY}$(( SUFFIX + 1 ))"
  fi
else
  NEW_BUILD="$TODAY"
fi

echo "$CURRENT -> $NEW_BUILD"

if $DRY_RUN; then
  echo "(dry run, no changes written)"
  exit 0
fi

sed -i '' "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: ${NEW_BUILD}/" "$PROJECT_YML"

if command -v xcodegen &>/dev/null; then
  xcodegen generate 2>&1
  echo "Done. Build number is now $NEW_BUILD"
else
  echo "Done. Build number is now $NEW_BUILD (run xcodegen generate manually)"
fi
