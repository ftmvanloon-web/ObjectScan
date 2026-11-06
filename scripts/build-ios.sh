#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Run this on the macOS GitHub runner. Apple credentials are not needed for this build.
xcodebuild \
  -project ObjectScan.xcodeproj \
  -scheme ObjectScan \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  build

python3 scripts/package_ipa.py \
  --app build/Build/Products/Release-iphoneos/ObjectScan.app \
  --output dist/ObjectScan-unsigned.ipa
