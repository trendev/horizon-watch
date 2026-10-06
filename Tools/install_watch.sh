#!/bin/sh
# Builds Horizon, signs it with your team and installs it on the connected Apple Watch.
#
#     Tools/install_watch.sh
#
# Before the first run: your team in Configuration/Local.xcconfig, the paired iPhone plugged
# into the Mac, Developer Mode on for the iPhone and the watch, the watch unlocked. See the
# README, "Install on your watch". With a free Apple account the app stops opening after
# 7 days: run this again to renew it. Settings are kept.
set -e
cd "$(dirname "$0")/.."

if ! grep -q "^DEVELOPMENT_TEAM *= *[A-Z0-9]" Configuration/Local.xcconfig 2>/dev/null; then
    echo "No team found. Create Configuration/Local.xcconfig with: DEVELOPMENT_TEAM = <your team id>" >&2
    exit 1
fi

xcodegen generate >/dev/null
echo "Looking for an Apple Watch..."
WATCH="$(xcodebuild -project Horizon.xcodeproj -scheme Horizon -showdestinations 2>/dev/null \
    | grep "platform:watchOS," | grep -v placeholder | grep -v "error:" \
    | sed -E 's/.*id:([^,]+),.*/\1/' | head -1)"
if [ -z "$WATCH" ]; then
    echo "No Apple Watch is ready. Check that the iPhone is plugged in and unlocked, that the" >&2
    echo "watch is unlocked and near it, and that Developer Mode is on for both. Xcode can need" >&2
    echo "a few minutes to prepare a watch the first time: Window > Devices and Simulators." >&2
    exit 1
fi

echo "Building and signing for watch $WATCH..."
LOG="$(mktemp)"
if ! xcodebuild -project Horizon.xcodeproj -scheme Horizon -destination "platform=watchOS,id=$WATCH" \
    -derivedDataPath build/dd-device -allowProvisioningUpdates build >"$LOG" 2>&1; then
    grep -E "error:" "$LOG" | sed -E 's/^.*error: /error: /' | sort -u >&2
    echo "Full log: $LOG" >&2
    exit 1
fi
rm -f "$LOG"

echo "Installing (this goes through the iPhone and can take a minute)..."
xcrun devicectl device install app --device "$WATCH" build/dd-device/Build/Products/Debug-watchos/Horizon.app >/dev/null
xcrun devicectl device process launch --device "$WATCH" fr.trendev.horizon >/dev/null 2>&1 \
    || echo "Installed, but it could not be opened from here. Open Horizon on the watch."
echo "Horizon is installed on the watch."
