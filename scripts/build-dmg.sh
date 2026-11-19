#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
stage="$(mktemp -d "${TMPDIR:-/tmp}/doorsound-dmg.XXXXXX")"
mount=""
cleanup() {
  if [[ -n "$mount" ]]; then hdiutil detach "$mount" -quiet || true; fi
  rm -rf "$stage"
}
trap cleanup EXIT
cp -R build/DoorSound.app "$stage/"
ln -s /Applications "$stage/Applications"
mkdir -p "$stage/.background"
swift scripts/dmg-background.swift "$stage/.background/install.png"
rm -f build/DoorSound.dmg build/DoorSound-rw.dmg
hdiutil create -quiet -volname DoorSound -srcfolder "$stage" -format UDRW build/DoorSound-rw.dmg
mount=$(hdiutil attach -nobrowse -readwrite build/DoorSound-rw.dmg | awk -F '\t' '/\/Volumes\// {print $NF; exit}')
if [[ -z "$mount" ]]; then echo "Could not mount DMG" >&2; exit 1; fi
# Finder writes the window and icon arrangement into the image's .DS_Store.
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "DoorSound"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 140, 800, 500}
        set opts to icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set background picture of opts to file ".background:install.png"
        set position of item "DoorSound.app" of container window to {150, 170}
        set position of item "Applications" of container window to {450, 170}
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT
sync
hdiutil detach "$mount" -quiet
mount=""
hdiutil convert build/DoorSound-rw.dmg -quiet -format UDZO -o build/DoorSound.dmg
rm -f build/DoorSound-rw.dmg
echo "Built build/DoorSound.dmg"
