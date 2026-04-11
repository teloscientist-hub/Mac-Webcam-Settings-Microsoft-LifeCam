#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
APP_DIR="$ROOT_DIR/.build/WebcamSettings.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_BINARY="$BUILD_DIR/WebcamSettings"
INFO_PLIST_SOURCE="$ROOT_DIR/Support/WebcamSettings-Info.plist"

if [[ ! -x "$SOURCE_BINARY" ]]; then
  echo "Expected built binary at $SOURCE_BINARY"
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$SOURCE_BINARY" "$MACOS_DIR/WebcamSettings"
cp "$INFO_PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/WebcamSettings"

echo "$APP_DIR"
