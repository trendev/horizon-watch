#!/bin/sh
# Launches Horizon on the real clock and prints how many notifications it scheduled.
# Expect "pending=61 refill=true" with both alarms and the follow-up on: 15 days x 4 + 1,
# under the system limit of 64. Notifications must have been allowed on that simulator first
# (run the UI test testGrantingNotificationsFromOnboarding once).
set -e
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-Apple Watch Ultra 3 (49mm)}"
LOG="$(mktemp)"
xcrun simctl terminate "$DEVICE" fr.trendev.horizon >/dev/null 2>&1 || true
xcrun simctl launch --console-pty "$DEVICE" fr.trendev.horizon \
    -horizonLocation "${LOCATION:-48.8566,2.3522}" -horizonSkipOnboarding YES "$@" >"$LOG" 2>&1 &
sleep 10
grep -a HORIZON "$LOG" | tail -2
xcrun simctl terminate "$DEVICE" fr.trendev.horizon >/dev/null 2>&1 || true
rm -f "$LOG"
