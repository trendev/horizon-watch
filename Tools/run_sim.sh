#!/bin/sh
# Builds Horizon, installs it on a watch simulator, launches it with the given arguments
# and saves a screenshot.
#
#     Tools/run_sim.sh out.png [-AppleLanguages "(de)"] [-horizonNow 2026-09-29T16:17:00+02:00 ...]
#
# DEVICE picks the simulator (default: Apple Watch Ultra 3 (49mm)). SKIP_BUILD=1 reuses the last build.
set -e
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-Apple Watch Ultra 3 (49mm)}"
OUT="$1"
shift
if [ -z "$SKIP_BUILD" ]; then
    xcodegen generate >/dev/null
    xcodebuild -project Horizon.xcodeproj -scheme Horizon \
        -destination "platform=watchOS Simulator,name=$DEVICE" -derivedDataPath build/dd build \
        2>&1 | grep -E "error|warning: |BUILD" | grep -v appintentsmetadata | sort -u
fi
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
# simctl boots the simulator without a window; this shows it.
open -a Simulator
xcrun simctl terminate "$DEVICE" fr.trendev.horizon >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE" build/dd/Build/Products/Debug-watchsimulator/Horizon.app
xcrun simctl launch "$DEVICE" fr.trendev.horizon "$@" >/dev/null
sleep "${WAIT:-6}"
xcrun simctl io "$DEVICE" screenshot "$OUT" >/dev/null 2>&1
echo "Horizon is running in the Simulator window ($DEVICE). Screenshot: $OUT"
