#!/bin/bash
# Runs the tests. With only Command Line Tools installed, swift-testing needs these paths.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV=/Library/Developer/CommandLineTools/Library/Developer
if [ -d "$DEV/Frameworks/Testing.framework" ] && ! xcode-select -p | grep -q Xcode.app; then
  swift test -Xswiftc -F"$DEV/Frameworks" -Xlinker -F"$DEV/Frameworks" \
    -Xlinker -rpath -Xlinker "$DEV/Frameworks" -Xlinker -rpath -Xlinker "$DEV/usr/lib"
else
  swift test
fi
