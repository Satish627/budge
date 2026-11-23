#!/bin/bash
# Builds Budge and installs it into /Applications, replacing any older copy.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh
pkill -x Budge || true
sleep 1
rm -rf /Applications/Budge.app
ditto .build/Budge.app /Applications/Budge.app
# Ask macOS to re-read the app so the launcher shows the current icon.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Budge.app
open /Applications/Budge.app
echo "Installed /Applications/Budge.app"
