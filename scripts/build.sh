#!/bin/sh
# TidyMac — by M.Alshmmari
#
# Builds build/TidyMac.app (Apple Silicon + Intel).
#   ./scripts/build.sh            build only
#   ./scripts/build.sh --install  build, copy to /Applications and open it
#
# Signs with SIGN_ID if set, otherwise the first Apple Development identity in the
# keychain, otherwise ad-hoc. A real identity lets macOS remember the app's
# folder permissions between builds.
set -e
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/TidyMac"

APP=build/TidyMac.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/TidyMac"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/MenuBarIcon.png Resources/MenuBarIcon@2x.png "$APP/Contents/Resources/"

if [ -z "$SIGN_ID" ]; then
  SIGN_ID=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ { print $2; exit }')
fi
codesign --force --options runtime --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP (signed: ${SIGN_ID:-ad-hoc})"

if [ "$1" = "--install" ]; then
  pkill -x TidyMac 2>/dev/null || true
  rm -rf /Applications/TidyMac.app
  cp -R "$APP" /Applications/
  open /Applications/TidyMac.app
  echo "Installed to /Applications and opened"
fi
