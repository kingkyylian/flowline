#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET_PATH="$ROOT_DIR/Resources/Flowline.iconset"
ICNS_PATH="$ROOT_DIR/Resources/Flowline.icns"
MODULE_CACHE_PATH="$ROOT_DIR/.build/icon-module-cache"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required tool: $1" >&2
    exit 2
  fi
}

require_tool swift
require_tool iconutil

mkdir -p "$MODULE_CACHE_PATH"
swift -module-cache-path "$MODULE_CACHE_PATH" "$ROOT_DIR/script/generate_app_icon.swift" "$ICONSET_PATH"

iconutil -c icns "$ICONSET_PATH" -o "$ICNS_PATH"
rm -rf "$ICONSET_PATH"

echo "Generated $ICNS_PATH"
