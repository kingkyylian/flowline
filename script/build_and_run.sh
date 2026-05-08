#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Flowline"
PRODUCT_NAME="Flowline"
BUNDLE_ID="dev.kyylian.flowline"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_PATH="$DIST_DIR/$APP_NAME.app"
EXECUTABLE_PATH="$ROOT_DIR/.build/debug/$PRODUCT_NAME"
MODE="${1:-}"

resolve_codesign_identity() {
  if [[ -n "${FLOWLINE_CODESIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$FLOWLINE_CODESIGN_IDENTITY"
    return
  fi

  security find-identity -v -p codesigning 2>/dev/null |
    sed -n 's/.*"\(.*\)".*/\1/p' |
    head -n 1
}

cd "$ROOT_DIR"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  pkill -x "$APP_NAME" || true
fi

swift build

rm -rf "$BUNDLE_PATH"
mkdir -p "$BUNDLE_PATH/Contents/MacOS"
cp "$EXECUTABLE_PATH" "$BUNDLE_PATH/Contents/MacOS/$APP_NAME"

cat > "$BUNDLE_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSCalendarsUsageDescription</key>
  <string>Flowline shows the next local calendar event in the top-edge context bar.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Flowline reads local now-playing details from Spotify or Music to show the current track in the notch.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

SIGN_IDENTITY="$(resolve_codesign_identity || true)"
if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$BUNDLE_PATH"
  if codesign --verify --deep "$BUNDLE_PATH" >/dev/null 2>&1; then
    echo "Signed Flowline with identity: $SIGN_IDENTITY"
  else
    echo "warning: identity '$SIGN_IDENTITY' is not trusted for local code signing; falling back to ad-hoc signing." >&2
    codesign --force --deep --sign - "$BUNDLE_PATH"
    echo "warning: signed Flowline ad-hoc; macOS Accessibility may need to be re-granted after rebuilds." >&2
  fi
else
  codesign --force --deep --sign - "$BUNDLE_PATH"
  echo "warning: signed Flowline ad-hoc; macOS Accessibility may need to be re-granted after rebuilds." >&2
fi

/usr/bin/open -n "$BUNDLE_PATH"

case "$MODE" in
  --verify)
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running"
    ;;
  --logs)
    /usr/bin/log stream --style compact --predicate "process == '$APP_NAME'"
    ;;
  --telemetry)
    /usr/bin/log stream --info --style compact --predicate "process == '$APP_NAME'"
    ;;
  --debug)
    echo "Debug bundle staged at $BUNDLE_PATH"
    ;;
  "")
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 2
    ;;
esac
