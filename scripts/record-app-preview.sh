#!/bin/bash
# Records the App Store preview walkthrough on the 6.9" simulator.
set -u
UDID="1C6B1F64-3D13-45E3-8655-BC4F333D22EE"   # iPhone 17 Pro Max (6.9")
OUT="$HOME/Desktop/Tweli-store-screenshots/preview"
RAW="$OUT/raw-1320x2868.mov"
mkdir -p "$OUT"
rm -f "$RAW"

xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
xcrun simctl ui "$UDID" appearance dark >/dev/null 2>&1

cd /Users/shalinthadithyan/Desktop/master/Tweli

# Build FIRST, outside the recording. Otherwise the film opens with however
# long the compile takes, showing whatever the simulator was left on.
echo "building for testing..."
xcodebuild build-for-testing \
  -project Tweli.xcodeproj -scheme Tweli \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath /tmp/tweli-dd -quiet 2>&1 | grep -E "error:|BUILD FAILED" | head -5

# Reset the screen so no leftover sheet from an earlier run opens the film.
xcrun simctl terminate "$UDID" me.adithyan.shalinth.Tweli 2>/dev/null
sleep 1

echo "recording -> $RAW"
xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW" &
REC_PID=$!
sleep 2

# -parallel-testing-enabled NO is the whole point: with it on, xcodebuild runs
# UI tests on a CLONED simulator and the recording films the original sitting
# idle. That produced a 21-second video of one frozen frame.
xcodebuild test-without-building \
  -project Tweli.xcodeproj -scheme Tweli \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath /tmp/tweli-dd \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:TweliUITests/StorePreviewWalkthrough 2>&1 \
  | grep -E "Test Case.*(passed|failed)|error:|TEST (SUCCEEDED|FAILED)" | head -10

sleep 2
# SIGINT is what makes simctl finalise the movie; SIGKILL leaves it unplayable.
kill -INT "$REC_PID" 2>/dev/null
wait "$REC_PID" 2>/dev/null

echo "--- result ---"
ls -lh "$RAW" 2>/dev/null
mdls -name kMDItemDurationSeconds -name kMDItemPixelWidth -name kMDItemPixelHeight "$RAW" 2>/dev/null
