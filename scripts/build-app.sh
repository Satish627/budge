#!/bin/bash
# Builds Budge.app into the hidden .build folder, so macOS doesn't list it as a second app.
# Needs only Xcode Command Line Tools. To install, use scripts/install.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=".build/Budge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Budge "$APP/Contents/MacOS/Budge"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"   # ad-hoc signature, enough to run on your own Mac
echo "Built $APP"
