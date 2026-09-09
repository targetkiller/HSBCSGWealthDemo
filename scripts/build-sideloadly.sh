#!/bin/bash
set -euo pipefail

# Build a device app for Sideloadly to sign with each tester's Apple Account.
project_root="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: $0 [output-directory]"
  echo "Default: $project_root/build/Sideloadly"
  exit 0
fi
if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [output-directory]" >&2
  exit 1
fi

output_dir="${1:-$project_root/build/Sideloadly}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
derived_data="$output_dir/DerivedData"
build_log="$output_dir/build.log"
app_path="$derived_data/Build/Products/Release-iphoneos/WealthHub.app"

echo "Building HSBC SG for iPhone and iPad (Release, iOS 17+)..."
if ! xcodebuild \
  -project "$project_root/WealthHub.xcodeproj" \
  -scheme WealthHub \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= \
  ENABLE_DEBUG_DYLIB=NO \
  -quiet build > "$build_log" 2>&1; then
  tail -n 60 "$build_log" >&2
  echo "Build failed. Full log: $build_log" >&2
  exit 1
fi

platform="$(/usr/bin/plutil -extract DTPlatformName raw -o - "$app_path/Info.plist")"
supported_platform="$(/usr/bin/plutil -extract CFBundleSupportedPlatforms.0 raw -o - "$app_path/Info.plist")"
executable="$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$app_path/Info.plist")"
if [ "$platform" != "iphoneos" ] || [ "$supported_platform" != "iPhoneOS" ]; then
  echo "Expected an iOS device build; refusing to package a simulator app." >&2
  exit 1
fi
xcrun lipo "$app_path/$executable" -verify_arch arm64

staging_dir="$(mktemp -d "$output_dir/.ipa-stage.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
mkdir "$staging_dir/Payload"
/usr/bin/ditto --norsrc --noextattr --noqtn "$app_path" "$staging_dir/Payload/WealthHub.app"
if [ -e "$staging_dir/Payload/WealthHub.app/embedded.mobileprovision" ]; then
  echo "Unexpected provisioning profile in the unsigned build." >&2
  exit 1
fi

# A fresh archive avoids retaining old files when rebuilding a release.
/usr/bin/ditto -c -k --norsrc --noextattr --noqtn --keepParent \
  "$staging_dir/Payload" "$staging_dir/HSBC-SG.ipa"
/usr/bin/unzip -tq "$staging_dir/HSBC-SG.ipa"
mv "$staging_dir/HSBC-SG.ipa" "$output_dir/HSBC-SG.ipa"
(
  cd "$output_dir"
  /usr/bin/shasum -a 256 HSBC-SG.ipa > HSBC-SG.ipa.sha256
)

echo "IPA: $output_dir/HSBC-SG.ipa"
echo "SHA-256: $output_dir/HSBC-SG.ipa.sha256"
echo "Open this IPA in Sideloadly and sign it with your own Apple Account."
