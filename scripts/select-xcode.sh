#!/bin/bash
set -euo pipefail
# Pin the toolchain and iOS SDK verified in the macos-15 runner manifest.
sudo xcode-select -s /Applications/Xcode_26.3.app/Contents/Developer
xcodebuild -version
