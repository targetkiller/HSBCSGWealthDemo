#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-all}"
if [ "$mode" = "--help" ] || [ "$mode" = "-h" ]; then
  echo "Usage: $0 [all|iphone|ipad]"
  echo "Requires Xcode, Node.js, and available iPhone 17 Pro Max / iPad Pro 13-inch (M5) simulators."
  echo "Runs only the opt-in native screenshot test; no uploads or image transformations."
  exit 0
fi
if [ "$#" -gt 1 ] || { [ "$mode" != "all" ] && [ "$mode" != "iphone" ] && [ "$mode" != "ipad" ]; }; then
  echo "Expected all, iphone, or ipad." >&2
  exit 1
fi
command -v node > /dev/null
output_root="$project_root/build/AppStoreScreenshots"
mkdir -p "$output_root"
run_dir="$(mktemp -d "$output_root/$(date -u +%Y%m%d-%H%M%S).XXXXXX")"
derived_data="$output_root/DerivedData"
current_device=""
trap 'if [ -n "$current_device" ]; then xcrun simctl status_bar "$current_device" clear >/dev/null 2>&1 || true; fi' EXIT

node "$project_root/scripts/app-store-screenshot-files.mjs" devices "$mode" > "$run_dir/devices.tsv"
while IFS=$'\t' read -r group device_id device_name runtime; do
  device_dir="$run_dir/$group"
  mkdir -p "$device_dir"
  current_device="$device_id"
  echo "Capturing $device_name ($runtime)..."
  xcrun simctl boot "$device_id" > /dev/null 2>&1 || true
  xcrun simctl bootstatus "$device_id" -b > "$device_dir/boot.log" 2>&1
  xcrun simctl ui "$device_id" appearance light
  xcrun simctl status_bar "$device_id" override --time '9:41' \
    --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState discharging --batteryLevel 100
  if ! TEST_RUNNER_APP_STORE_SCREENSHOTS=1 xcodebuild \
    -project "$project_root/WealthHub.xcodeproj" -scheme WealthHub \
    -configuration Debug -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath "$derived_data" -resultBundlePath "$device_dir/Capture.xcresult" \
    -only-testing:WealthHubUITests/WealthHubUITests/testCaptureAppStoreScreenshots \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    -quiet test > "$device_dir/test.log" 2>&1; then
    tail -n 60 "$device_dir/test.log" >&2
    echo "Screenshot test failed. Log: $device_dir/test.log" >&2
    exit 1
  fi
  xcrun xcresulttool export attachments --path "$device_dir/Capture.xcresult" \
    --output-path "$device_dir/attachments" > "$device_dir/export.log" 2>&1
  node "$project_root/scripts/app-store-screenshot-files.mjs" export \
    "$device_dir" "$group" "$device_name" "$runtime" \
    "$derived_data/Build/Products/Debug-iphonesimulator/WealthHub.app/Info.plist"
  xcrun simctl status_bar "$device_id" clear
  current_device=""
done < "$run_dir/devices.tsv"
node "$project_root/scripts/app-store-screenshot-files.mjs" index "$run_dir"
echo "Screenshot index: $run_dir/README.md"
