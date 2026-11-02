#!/bin/bash
#
# Set the next release build number in project.yml and regenerate the Xcode project.
#
# The number uses the date-based TestFlight rule (YYYYMMDD, YYYYMMDD1, ...) and is
# greater than both the committed number and the latest App Store Connect build of
# the marketing version. Requires ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH.
#
# Usage:
#   ./scripts/bump-build.sh           # bump and regenerate Xcode project
#   ./scripts/bump-build.sh --dry-run # preview without writing

set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-}" in
  "") exec bundle exec fastlane ios bump_build ;;
  --dry-run) exec bundle exec fastlane ios bump_build dry_run:true ;;
  *) echo "usage: $0 [--dry-run]" >&2; exit 64 ;;
esac
