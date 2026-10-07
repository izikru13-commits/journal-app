#!/usr/bin/env bash
# Usage: scripts/install-device.sh [DEVICE_ID]
# Builds a signed Debug build (provisioning profiles are created automatically) and installs it.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f Config/Local.xcconfig ]] || { echo "Run scripts/setup.sh first." >&2; exit 1; }
xcodegen generate >/dev/null

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/connected|available/ && /iPhone/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-/) {print $i; exit}}')
fi
[[ -n "$DEVICE" ]] || { echo "No iPhone found. Connect it with a cable, unlock it, and trust this Mac." >&2; exit 1; }
echo "Device: $DEVICE"
mkdir -p build

if ! xcodebuild \
  -project Rega.xcodeproj -scheme Rega -configuration Debug \
  -destination "generic/platform=iOS" -derivedDataPath build \
  -allowProvisioningUpdates build > build/install.log 2>&1; then
  grep -E "error:" build/install.log | sort -u >&2
  echo "Build failed. Full log: build/install.log" >&2
  exit 1
fi
grep -E "warning:" build/install.log | grep "/rega/" | sort -u || true

APP=build/Build/Products/Debug-iphoneos/Rega.app
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" com.neriya.rega || true
echo "Installed."
