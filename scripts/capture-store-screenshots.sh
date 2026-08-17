#!/bin/bash
# App Store screenshot set — 10 shots, 6.9" iPhone (1320x2868), dark.
set -u
UDID="1C6B1F64-3D13-45E3-8655-BC4F333D22EE"   # iPhone 17 Pro Max
BID="me.adithyan.shalinth.Tweli"
APP="/tmp/tweli-dd/Build/Products/Debug-iphonesimulator/Tweli.app"
MODE="${1:-dark}"
OUT="$HOME/Desktop/Tweli-store-screenshots/$MODE"
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
xcrun simctl install "$UDID" "$APP" || exit 1
xcrun simctl ui "$UDID" appearance "$MODE" >/dev/null 2>&1

# name|extra env (space separated KEY=VAL), applied on top of the base set
shots=(
  "01-onboarding|TWELI_TUTORIAL_PAGE=0"
  "02-signin|TWELI_SKIP_ONBOARDING=1 TWELI_STAGE=signin"
  "03-loading|TWELI_SKIP_ONBOARDING=1 TWELI_RESTORE=k2 TWELI_CAPTURE=1"
  "04-home|TWELI_SKIP_ONBOARDING=1 TWELI_CAPTURE=1 TWELI_TAB=0"
  "05-distance|TWELI_SKIP_ONBOARDING=1 TWELI_CAPTURE=1 TWELI_TAB=0 TWELI_DISTANCE=1"
  "06-moods|TWELI_SKIP_ONBOARDING=1 TWELI_CAPTURE=1 TWELI_TAB=2"
  "07-reminders|TWELI_SKIP_ONBOARDING=1 TWELI_CAPTURE=1 TWELI_TAB=1"
  "08-dates|TWELI_SKIP_ONBOARDING=1 TWELI_CAPTURE=1 TWELI_TAB=0 TWELI_DATES_SHEET=1"
  "09-letters|TWELI_SKIP_ONBOARDING=1 TWELI_CAPTURE=1 TWELI_TAB=3"
  "10-meet|TWELI_SKIP_ONBOARDING=1 TWELI_CAPTURE=1 TWELI_TAB=0 TWELI_MEET_SHEET=1"
)

for entry in "${shots[@]}"; do
  name="${entry%%|*}"
  extra="${entry#*|}"
  xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1
  sleep 1
  env_args=(SIMCTL_CHILD_TWELI_NO_LOCATION_ASK=1)
  for kv in $extra; do env_args+=("SIMCTL_CHILD_${kv}"); done
  env "${env_args[@]}" xcrun simctl launch "$UDID" "$BID" >/dev/null 2>&1
  sleep 10   # splash is ~4.5s; sheets animate in after
  xcrun simctl io "$UDID" screenshot "$OUT/${name}.png" >/dev/null 2>&1
  echo "captured ${name}.png"
done

echo "--- dimensions ---"
for f in "$OUT"/*.png; do
  echo "$(basename "$f"): $(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')"
done
