#!/bin/bash
# Builds "Budge.app" into ./build. Needs only Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP="build/Budge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Budge "$APP/Contents/MacOS/Budge"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"   # ad-hoc signature, enough to run on your own Mac
echo "Built $APP"
