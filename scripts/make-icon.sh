#!/bin/bash
# Draws the app icon (Waddle) and packs it into Resources/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build
TMP=$(mktemp -d)
.build/debug/Budge --icon "$TMP/icon.png"
SET="$TMP/AppIcon.iconset"
mkdir "$SET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$TMP/icon.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$TMP/icon.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
sips -z 256 256 "$TMP/icon.png" --out docs/icon.png >/dev/null
echo "Wrote Resources/AppIcon.icns"
