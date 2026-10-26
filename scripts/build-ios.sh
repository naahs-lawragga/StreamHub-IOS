#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LC_ALL=en_US.UTF-8
mkdir -p build
xcodegen generate --spec project.yml
xcodebuild -resolvePackageDependencies -project StreamHub.xcodeproj -scheme StreamHub
swift test --package-path Core
SIMULATOR_ID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(v["udid"] for k,a in sorted(d["devices"].items(),reverse=True) if "iOS" in k for v in a if v["name"].startswith("iPhone")))')
xcodebuild test -project StreamHub.xcodeproj -scheme StreamHub -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath build/DerivedData -resultBundlePath build/Tests.xcresult CODE_SIGNING_ALLOWED=NO
mkdir -p build/screenshots
# Capture a real build without a TMDB credential; this is the honest setup state.
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl install "$SIMULATOR_ID" build/DerivedData/Build/Products/Debug-iphonesimulator/StreamHub.app
xcrun simctl launch "$SIMULATOR_ID" com.streamhub.ios
sleep 3
xcrun simctl io "$SIMULATOR_ID" screenshot build/screenshots/setup.png
xcodebuild build -project StreamHub.xcodeproj -scheme StreamHub -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO "MARKETING_VERSION=${STREAMHUB_VERSION:-0.1.0}" "CURRENT_PROJECT_VERSION=${GITHUB_RUN_NUMBER:-1}" "STREAMHUB_SOURCE_URL=${STREAMHUB_SOURCE_URL:-}"
python3 scripts/package-ipa.py build/DerivedData/Build/Products/Release-iphoneos/StreamHub.app build/StreamHub-unsigned.ipa
shasum -a 256 build/StreamHub-unsigned.ipa > build/StreamHub-unsigned.ipa.sha256
