#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:---help}"
if [ "$mode" = "--help" ] || [ "$mode" = "-h" ]; then
  cat <<'USAGE'
Usage: ./scripts/testflight.sh preflight|archive

preflight  Build and inspect an unsigned device archive. Cannot be uploaded.
archive    Build a signed archive for Xcode Organizer. Does not upload it.

Optional environment variables:
  TESTFLIGHT_TEAM_ID       Paid Apple Developer team ID; otherwise use Xcode settings.
  TESTFLIGHT_VERSION       Marketing version, for example 1.0.1.
  TESTFLIGHT_BUILD_NUMBER  Unused build number, for example 3.
  TESTFLIGHT_OUTPUT_DIR    Output root; defaults to build/TestFlight.

Archive mode uses automatic signing and allows Xcode to manage provisioning.
Sign in to the paid development team in Xcode before running archive mode.
USAGE
  exit 0
fi
if [ "$#" -ne 1 ] || { [ "$mode" != "preflight" ] && [ "$mode" != "archive" ]; }; then
  echo "Expected preflight or archive. Use --help for details." >&2
  exit 1
fi

sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
if [ "${sdk_version%%.*}" -lt 26 ]; then
  echo "App Store Connect currently requires the iOS 26 SDK or later. Select Xcode 26+." >&2
  exit 1
fi

settings=(ENABLE_DEBUG_DYLIB=NO)
if [ -n "${TESTFLIGHT_VERSION:-}" ]; then
  if ! [[ "$TESTFLIGHT_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "TESTFLIGHT_VERSION must be a numeric version such as 1.0.1." >&2
    exit 1
  fi
  settings+=("MARKETING_VERSION=$TESTFLIGHT_VERSION")
fi
if [ -n "${TESTFLIGHT_BUILD_NUMBER:-}" ]; then
  if ! [[ "$TESTFLIGHT_BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "TESTFLIGHT_BUILD_NUMBER must be a numeric build number." >&2
    exit 1
  fi
  settings+=("CURRENT_PROJECT_VERSION=$TESTFLIGHT_BUILD_NUMBER")
fi
if [ "$mode" = "preflight" ]; then
  settings+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM=)
else
  if [ -n "${TESTFLIGHT_TEAM_ID:-}" ]; then
    if ! [[ "$TESTFLIGHT_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
      echo "TESTFLIGHT_TEAM_ID must be the 10-character Apple Developer team ID." >&2
      exit 1
    fi
    settings+=("DEVELOPMENT_TEAM=$TESTFLIGHT_TEAM_ID")
  fi
  settings+=(CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates)
fi

output_root="${TESTFLIGHT_OUTPUT_DIR:-$project_root/build/TestFlight}"
mkdir -p "$output_root"
output_root="$(cd "$output_root" && pwd)"
run_dir="$(mktemp -d "$output_root/$mode-$(date -u +%Y%m%d-%H%M%S).XXXXXX")"
archive_path="$run_dir/HSBC-SG.xcarchive"
build_log="$run_dir/build.log"
echo "Creating $mode archive with iOS SDK $sdk_version..."

if ! xcodebuild \
  -project "$project_root/WealthHub.xcodeproj" \
  -scheme WealthHub \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$output_root/DerivedData-$mode" \
  -archivePath "$archive_path" \
  "${settings[@]}" \
  -quiet archive > "$build_log" 2>&1; then
  tail -n 60 "$build_log" >&2
  echo "Archive failed. Log: $build_log" >&2
  if [ "$mode" = "archive" ]; then
    echo "Check the Bundle ID, paid team membership, and Xcode account/signing settings." >&2
  fi
  exit 1
fi

app_path="$archive_path/Products/Applications/WealthHub.app"
info="$app_path/Info.plist"
manifest="$app_path/PrivacyInfo.xcprivacy"
/usr/bin/plutil -lint "$info" "$manifest" > /dev/null
platform="$(/usr/bin/plutil -extract DTPlatformName raw -o - "$info")"
executable="$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$info")"
if [ "$platform" != "iphoneos" ]; then
  echo "Expected an iPhoneOS device archive." >&2
  exit 1
fi
xcrun lipo "$app_path/$executable" -verify_arch arm64
/usr/bin/plutil -extract CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName raw -o - "$info" > /dev/null
/usr/bin/plutil -extract 'UISupportedInterfaceOrientations~ipad' xml1 -o - "$info" > /dev/null
/usr/bin/plutil -extract ITSAppUsesNonExemptEncryption raw -o - "$info" > /dev/null

if [ "$mode" = "archive" ]; then
  /usr/bin/codesign --verify --deep --strict "$app_path"
  if [ ! -f "$app_path/embedded.mobileprovision" ]; then
    echo "The archive has no provisioning profile. Check automatic signing in Xcode." >&2
    exit 1
  fi
fi

{
  echo "Mode: $mode"
  echo "SDK: $sdk_version"
  echo "Bundle ID: $(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$info")"
  echo "Version: $(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$info")"
  echo "Build: $(/usr/bin/plutil -extract CFBundleVersion raw -o - "$info")"
  echo "Minimum iOS: $(/usr/bin/plutil -extract MinimumOSVersion raw -o - "$info")"
  echo "Checks: device ARM64, app icon, privacy manifest, iPad orientations, export-compliance key"
  echo "Archive: $archive_path"
  echo "Log: $build_log"
  if [ "$mode" = "preflight" ]; then
    echo "Unsigned preflight only. This archive cannot be uploaded to TestFlight."
  else
    echo "Double-click the .xcarchive above in Finder to open it in Xcode Organizer."
    echo "Then choose Distribute App > App Store Connect > Upload."
    echo "Paid team eligibility, upload validation, processing and Beta App Review are checked by Apple."
  fi
} | tee "$run_dir/validation.txt"
