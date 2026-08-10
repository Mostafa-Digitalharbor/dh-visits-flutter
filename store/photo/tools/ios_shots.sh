#!/usr/bin/env bash
# Captures App Store screenshots on the iOS Simulator — macOS only.
#
#   bash store/photo/tools/ios_shots.sh                       # iPhone 16 Pro Max (1290x2796)
#   bash store/photo/tools/ios_shots.sh "iPhone 16 Pro"       # other device
#   SKIP_BUILD=1 bash store/photo/tools/ios_shots.sh          # app already installed
#
# Why this exists: build 1.0 (4) was rejected under App Store guideline 2.3.10
# because the uploaded screenshots were Android captures — Android status bar and
# gesture pill. App Store shots must come from an iOS device or simulator.
# See store/appstore/apple-review-2026-08-06.md.
#
# Output: store/photo/ios/*.png at the simulator's native size, which for
# iPhone 16 Pro Max is exactly the 6.9" App Store size (1290x2796) — no resizing.
# Then run compose.ps1 -Platform ios on Windows (or upload these raw).

set -euo pipefail

DEVICE="${1:-iPhone 16 Pro Max}"
BUNDLE_ID="net.digitalharbor.visits"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUT="$ROOT/store/photo/ios"
mkdir -p "$OUT"

echo "==> booting $DEVICE"
UDID="$(xcrun simctl list devices available | grep -m1 -F "$DEVICE (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
if [ -z "$UDID" ]; then
  echo "device '$DEVICE' not found. Available:" >&2
  xcrun simctl list devices available >&2
  exit 1
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$UDID" -b

# Clean iOS status bar: 9:41, full bars, full battery, no carrier clutter.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  # Debug is the ONLY mode the tool accepts for a simulator build
  # (`RELEASE mode is not supported for simulators.`). That is fine here: debug
  # never tree-shakes icons — the failure mode from scripts/build_release.* —
  # and the app already sets debugShowCheckedModeBanner: false, so there is no
  # DEBUG ribbon in the capture.
  echo "==> building for the simulator (debug)"
  cd "$ROOT"
  flutter clean
  flutter pub get
  flutter build ios --simulator --debug
  xcrun simctl install "$UDID" "$ROOT/build/ios/iphonesimulator/Runner.app"
fi

xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null

# Same four shots, same order, as the Play listing.
SHOTS=(
  "02_visits_list:Visits tab — the day's list, no test data visible"
  "01_visit_detail:Open a done visit — map, geofence badge, start/end markers"
  "03_dashboard:Manager account — Dashboard KPIs + team map"
  "04_analytics:Manager account — Analytics, weekly chart + by-employee"
)

echo
echo "==> navigate the simulator to each screen, then press Enter to capture."
for entry in "${SHOTS[@]}"; do
  name="${entry%%:*}"
  hint="${entry#*:}"
  printf '\n  [%s] %s\n  press Enter when the screen is ready > ' "$name" "$hint"
  read -r _
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png"
  size="$(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | awk '/pixel/{printf "%s ", $2}')"
  echo "  saved $name.png (${size%% })"
done

xcrun simctl status_bar "$UDID" clear
echo
echo "done -> $OUT"
echo "6.9\" App Store size is 1290x2796; anything else needs re-capture on iPhone 16 Pro Max."
