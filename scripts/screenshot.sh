#!/usr/bin/env bash
#
# Capture App Store-ready screenshots via the iOS Simulator (native simctl).
#
# Produces PNGs at the exact 6.9" iPhone size App Store Connect requires
# (1320 x 2868), with a clean marketing status bar (9:41, full battery/Wi-Fi).
#
# Usage:
#   scripts/screenshot.sh <name>     capture current screen  -> screenshots/<name>.png
#   scripts/screenshot.sh --launch-demo
#   scripts/screenshot.sh --clear    remove the status-bar override (restore live clock)
#
# Build/install/launch the app first (see .claude/skills/run-app/SKILL.md), then
# drive it to the screen you want and run this with a name, e.g.
#   scripts/screenshot.sh 01-dashboard
#
set -euo pipefail

DEVICE="iPhone 17 Pro Max"   # 6.9" -> 1320 x 2868, the only iPhone size App Store now requires
OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/screenshots"
APP_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/build/DerivedData/Build/Products/Debug-iphonesimulator/DSContainerManager.app"
BUNDLE_ID="com.bystritski.DSContainerManager"

boot() {
  xcrun simctl boot "$DEVICE" 2>/dev/null || true   # ok if already booted
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null
}

if [[ "${1:-}" == "--clear" ]]; then
  boot
  xcrun simctl status_bar "$DEVICE" clear
  echo "status bar override cleared"
  exit 0
fi

if [[ "${1:-}" == "--launch-demo" ]]; then
  boot
  if [[ ! -d "$APP_PATH" ]]; then
    echo "app not found at $APP_PATH" >&2
    echo "build first with xcodebuild -project DSContainerManager.xcodeproj -scheme DSContainerManager -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath build/DerivedData -skipMacroValidation build" >&2
    exit 1
	  fi
	  xcrun simctl install "$DEVICE" "$APP_PATH"
	  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
	  SIMCTL_CHILD_DSCM_DEMO_MODE=1 xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
	  exit 0
	fi

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "usage: $0 <name> | --launch-demo | --clear" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
boot

# Clean, App Store-friendly status bar.
xcrun simctl status_bar "$DEVICE" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

OUT="$OUT_DIR/$NAME.png"
xcrun simctl io "$DEVICE" screenshot --display primary --mask ignored "$OUT" >/dev/null 2>&1

SIZE="$(sips -g pixelWidth -g pixelHeight "$OUT" 2>/dev/null | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')"
echo "saved $OUT  ($SIZE)"
if [[ "$SIZE" != "1320x2868" ]]; then
  echo "  note: expected 1320x2868 for App Store 6.9\" — got $SIZE. Check the device is $DEVICE." >&2
fi
