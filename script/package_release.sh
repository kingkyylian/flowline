#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Flowline"
PRODUCT_NAME="Flowline"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
BUNDLE_PATH="$RELEASE_DIR/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-${FLOWLINE_VERSION:-0.1.0}.zip"
EXECUTABLE_PATH="$ROOT_DIR/.build/release/$PRODUCT_NAME"
ICON_PATH="$ROOT_DIR/Resources/Flowline.icns"

BUNDLE_ID="${FLOWLINE_BUNDLE_ID:-dev.kyylian.flowline}"
VERSION="${FLOWLINE_VERSION:-0.1.0}"
BUILD_NUMBER="${FLOWLINE_BUILD:-1}"
SIGN_IDENTITY="${FLOWLINE_DEVELOPER_ID_IDENTITY:-}"
MODE="${1:---archive}"

usage() {
  cat <<USAGE
Usage:
  FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID)" script/package_release.sh [--archive|--notarize]

Optional:
  FLOWLINE_BUNDLE_ID=dev.kyylian.flowline
  FLOWLINE_VERSION=0.1.0
  FLOWLINE_BUILD=1
  FLOWLINE_NOTARY_PROFILE=notarytool-profile

For --notarize, set FLOWLINE_NOTARY_PROFILE or provide APPLE_ID, APPLE_TEAM_ID,
and APPLE_APP_SPECIFIC_PASSWORD for xcrun notarytool.
USAGE
}

case "$MODE" in
  --archive|--notarize)
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "error: FLOWLINE_DEVELOPER_ID_IDENTITY is required for release packaging." >&2
  exit 2
fi

if [[ "$SIGN_IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "error: release packaging requires a Developer ID Application certificate." >&2
  exit 2
fi

if [[ ! -f "$ICON_PATH" ]]; then
  echo "error: missing app icon at $ICON_PATH. Run script/generate_app_icon.sh first." >&2
  exit 2
fi

cd "$ROOT_DIR"

swift build -c release

rm -rf "$BUNDLE_PATH" "$ZIP_PATH"
mkdir -p "$BUNDLE_PATH/Contents/MacOS" "$BUNDLE_PATH/Contents/Resources"
cp "$EXECUTABLE_PATH" "$BUNDLE_PATH/Contents/MacOS/$APP_NAME"
cp "$ICON_PATH" "$BUNDLE_PATH/Contents/Resources/Flowline.icns"

cat > "$BUNDLE_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>Flowline.icns</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSDesktopFolderUsageDescription</key>
  <string>Flowline watches the Desktop for new screenshots when Hold screenshot capture is enabled.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Flowline reads local now-playing details from Spotify or Music to show the current track in the notch.</string>
  <key>NSCalendarsUsageDescription</key>
  <string>Flowline shows the next local calendar event in the top-edge context bar.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Kyylian. All rights reserved.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BUNDLE_PATH"
codesign --verify --deep --strict --verbose=2 "$BUNDLE_PATH"

ditto -c -k --keepParent "$BUNDLE_PATH" "$ZIP_PATH"

if [[ "$MODE" == "--notarize" ]]; then
  if [[ -n "${FLOWLINE_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$FLOWLINE_NOTARY_PROFILE" --wait
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$ZIP_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  else
    echo "error: notarization requires FLOWLINE_NOTARY_PROFILE or Apple ID credentials." >&2
    exit 2
  fi

  xcrun stapler staple "$BUNDLE_PATH"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$BUNDLE_PATH" "$ZIP_PATH"
fi

echo "Release archive: $ZIP_PATH"
