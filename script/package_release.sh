#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Flowline"
PRODUCT_NAME="Flowline"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
BUNDLE_PATH="$RELEASE_DIR/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-${FLOWLINE_VERSION:-0.1.0}.zip"
MANIFEST_PATH="${ZIP_PATH%.zip}.manifest"
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
  FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID)" script/package_release.sh [--preflight|--archive|--notarize]

Optional:
  FLOWLINE_BUNDLE_ID=dev.kyylian.flowline   # reverse-DNS identifier
  FLOWLINE_VERSION=0.1.0                    # one to three dot-separated integers
  FLOWLINE_BUILD=1                          # one to three dot-separated integers
  FLOWLINE_NOTARY_PROFILE=notarytool-profile

For --notarize, set FLOWLINE_NOTARY_PROFILE or provide APPLE_ID, APPLE_TEAM_ID,
and APPLE_APP_SPECIFIC_PASSWORD for xcrun notarytool.
USAGE
}

require_developer_id_identity() {
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "error: FLOWLINE_DEVELOPER_ID_IDENTITY is required for release packaging." >&2
    exit 2
  fi

  if [[ "$SIGN_IDENTITY" != Developer\ ID\ Application:* ]]; then
    echo "error: release packaging requires a Developer ID Application certificate." >&2
    exit 2
  fi

  if ! security find-identity -v -p codesigning 2>/dev/null | grep -F -- "\"$SIGN_IDENTITY\"" >/dev/null; then
    echo "error: Developer ID Application identity is not installed: $SIGN_IDENTITY" >&2
    echo "       Install the certificate in Keychain Access or set FLOWLINE_DEVELOPER_ID_IDENTITY to an installed identity." >&2
    exit 2
  fi
}

notary_credentials_are_configured() {
  has_nonblank_value "${FLOWLINE_NOTARY_PROFILE:-}" \
    || apple_id_notary_credentials_are_configured
}

has_nonblank_value() {
  [[ "$1" =~ [^[:space:]] ]]
}

apple_id_notary_credentials_are_configured() {
  has_nonblank_value "${APPLE_ID:-}" \
    && has_nonblank_value "${APPLE_TEAM_ID:-}" \
    && has_nonblank_value "${APPLE_APP_SPECIFIC_PASSWORD:-}"
}

apple_team_id_is_valid() {
  [[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]
}

require_notary_credentials() {
  if ! notary_credentials_are_configured; then
    echo "error: notarization requires FLOWLINE_NOTARY_PROFILE or Apple ID credentials." >&2
    exit 2
  fi

  if ! has_nonblank_value "${FLOWLINE_NOTARY_PROFILE:-}" && ! apple_team_id_is_valid; then
    echo "error: APPLE_TEAM_ID is invalid: $APPLE_TEAM_ID" >&2
    echo "       Use the 10-character Apple Developer Team ID." >&2
    exit 2
  fi
}

require_release_metadata() {
  local bundle_id_regex='^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$'
  local version_regex='^[0-9]+(\.[0-9]+){0,2}$'

  if [[ ! "$BUNDLE_ID" =~ $bundle_id_regex ]]; then
    echo "error: FLOWLINE_BUNDLE_ID is invalid: $BUNDLE_ID" >&2
    echo "       Use a reverse-DNS identifier with letters, numbers, hyphens, and dots, for example dev.kyylian.flowline." >&2
    exit 2
  fi

  if [[ ! "$VERSION" =~ $version_regex ]]; then
    echo "error: FLOWLINE_VERSION is invalid: $VERSION" >&2
    echo "       Use one to three dot-separated integers, for example 0.1.0." >&2
    exit 2
  fi

  if [[ ! "$BUILD_NUMBER" =~ $version_regex ]]; then
    echo "error: FLOWLINE_BUILD is invalid: $BUILD_NUMBER" >&2
    echo "       Use one to three dot-separated integers, for example 1." >&2
    exit 2
  fi
}

archive_sha256() {
  local output
  output="$(shasum -a 256 "$1")"
  printf '%s\n' "${output%%[[:space:]]*}"
}

archive_size_bytes() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

release_git_commit() {
  git rev-parse HEAD 2>/dev/null || printf 'unknown'
}

write_release_manifest() {
  local notarized="$1"
  local archive_name="${ZIP_PATH##*/}"
  local sha256
  local size_bytes
  local git_commit
  local github_repository="${GITHUB_REPOSITORY:-unknown}"
  local github_run_id="${GITHUB_RUN_ID:-unknown}"
  local github_run_attempt="${GITHUB_RUN_ATTEMPT:-unknown}"
  local github_workflow="${GITHUB_WORKFLOW:-unknown}"
  local github_server_url="${GITHUB_SERVER_URL:-unknown}"
  local github_artifact_name="${FLOWLINE_GITHUB_ARTIFACT_NAME:-${GITHUB_ARTIFACT_NAME:-unknown}}"

  sha256="$(archive_sha256 "$ZIP_PATH")"
  size_bytes="$(archive_size_bytes "$ZIP_PATH")"
  git_commit="$(release_git_commit)"

  cat > "$MANIFEST_PATH" <<MANIFEST
flowline_release_manifest=1
archive_name=$archive_name
version=$VERSION
build=$BUILD_NUMBER
bundle_id=$BUNDLE_ID
git_commit=$git_commit
sha256=$sha256
size_bytes=$size_bytes
notarized=$notarized
github_repository=$github_repository
github_run_id=$github_run_id
github_run_attempt=$github_run_attempt
github_workflow=$github_workflow
github_server_url=$github_server_url
github_artifact_name=$github_artifact_name
MANIFEST
}

case "$MODE" in
  --preflight|--archive|--notarize)
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

require_developer_id_identity
require_release_metadata

if [[ ! -f "$ICON_PATH" ]]; then
  echo "error: missing app icon at $ICON_PATH. Run script/generate_app_icon.sh first." >&2
  exit 2
fi

if [[ "$MODE" == "--notarize" ]]; then
  require_notary_credentials
fi

if [[ "$MODE" == "--preflight" ]]; then
  echo "Release preflight passed for identity: $SIGN_IDENTITY"
  exit 0
fi

cd "$ROOT_DIR"

swift build -c release

rm -rf "$BUNDLE_PATH" "$ZIP_PATH" "$MANIFEST_PATH"
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

plutil -lint "$BUNDLE_PATH/Contents/Info.plist"

codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BUNDLE_PATH"
codesign --verify --deep --strict --verbose=2 "$BUNDLE_PATH"

ditto -c -k --keepParent "$BUNDLE_PATH" "$ZIP_PATH"
write_release_manifest false

if [[ "$MODE" == "--notarize" ]]; then
  if has_nonblank_value "${FLOWLINE_NOTARY_PROFILE:-}"; then
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$FLOWLINE_NOTARY_PROFILE" --wait
  elif apple_id_notary_credentials_are_configured && apple_team_id_is_valid; then
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
  spctl --assess --type execute --verbose "$BUNDLE_PATH"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$BUNDLE_PATH" "$ZIP_PATH"
  write_release_manifest true
fi

echo "Release archive: $ZIP_PATH"
