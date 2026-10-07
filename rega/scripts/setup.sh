#!/usr/bin/env bash
# Usage: scripts/setup.sh [TEAM_ID]
# Checks the toolchain, stores your Team ID (git-ignored) and generates Rega.xcodeproj.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Toolchain =="
xcodebuild -version
swift --version | head -1
if ! command -v brew >/dev/null; then
  echo "Homebrew is missing: https://brew.sh" >&2
  exit 1
fi
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen --version

TEAM_ID="${1:-}"
if [[ -z "$TEAM_ID" && -f Config/Local.xcconfig ]]; then
  TEAM_ID=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' Config/Local.xcconfig)
fi
if [[ -z "$TEAM_ID" ]]; then
  # Try the Apple Development certificate in the login keychain: "Apple Development: Name (XXXX)" -> OU is the team.
  TEAM_ID=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
fi
if [[ -z "$TEAM_ID" ]]; then
  echo "Team ID not found. Run: scripts/setup.sh ABCDE12345  (developer.apple.com/account -> Membership details)" >&2
  exit 1
fi
echo "DEVELOPMENT_TEAM = $TEAM_ID" > Config/Local.xcconfig
echo "Team ID: $TEAM_ID"

xcodegen generate
echo
echo "== Connected devices =="
xcrun devicectl list devices || true
echo
echo "Done. Open with: open Rega.xcodeproj   or install with: scripts/install-device.sh"
