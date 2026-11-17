#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="build/DoorSound.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/AppIcon.iconset
cp Crack/Info.plist "$app/Contents/Info.plist"
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable DoorSound' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.doorsound.app' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName DoorSound' "$plist"
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 13.0' "$plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile AppIcon' "$plist"
for size in 16 32 128 256 512; do
  cp "Crack/Assets.xcassets/AppIcon.appiconset/icon_${size}.png" "build/AppIcon.iconset/icon_${size}x${size}.png"
  double=$((size * 2))
  cp "Crack/Assets.xcassets/AppIcon.appiconset/icon_${double}.png" "build/AppIcon.iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
MACOSX_DEPLOYMENT_TARGET=13.0 swiftc -swift-version 5 -O Crack/*.swift -o "$app/Contents/MacOS/DoorSound"
codesign --force --sign - "$app"
echo "Built $app"
