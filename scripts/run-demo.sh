#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi
simulator_id="${1:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; ds=[d for group in json.load(sys.stdin)["devices"].values() for d in group if "iPhone" in d["name"]]; ds.sort(key=lambda d:d["state"]!="Booted"); print(ds[0]["udid"] if ds else "")')"
fi
if [ -z "$simulator_id" ]; then
  echo "No iPhone simulator installed. Add an iOS runtime in Xcode Settings > Components."
  exit 1
fi
xcodebuild -project WealthHub.xcodeproj -target WealthHub -sdk iphonesimulator \
  -configuration Debug "CONFIGURATION_BUILD_DIR=$project_root/build/Debug-iphonesimulator" \
  CODE_SIGNING_ALLOWED=NO "ARCHS=$(uname -m)" -quiet build
if ! xcrun simctl boot "$simulator_id" 2>/dev/null; then
  echo "Using the selected running simulator."
fi
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" "$project_root/build/Debug-iphonesimulator/WealthHub.app"
xcrun simctl launch "$simulator_id" com.wealthhub.demo
open -a Simulator
