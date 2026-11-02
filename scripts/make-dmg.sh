#!/bin/sh
# TidyMac — by M.Alshmmari
#
# Builds the app and packs it into build/TidyMac-<version>.dmg, with the usual
# "drag TidyMac to Applications" layout.
set -e
cd "$(dirname "$0")/.."

./scripts/build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DMG="build/TidyMac-$VERSION.dmg"
STAGE=build/dmg-stage

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R build/TidyMac.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "TidyMac" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Made $DMG"
