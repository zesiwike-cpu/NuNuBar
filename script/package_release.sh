#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NuNuBar"
APP_VERSION="${APP_VERSION:-0.15.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/$APP_NAME-$APP_VERSION-macOS-arm64.dmg"
STAGE_DIR="$(mktemp -d /tmp/NuNuBar-release.XXXXXX)"
trap 'rm -rf "$STAGE_DIR"' EXIT

APP_PATH="$DIST_DIR/$APP_NAME.app"
IMAGE_DIR="$STAGE_DIR/image"
TEMP_DMG="$STAGE_DIR/$APP_NAME.dmg"

mkdir -p "$DIST_DIR"
"$ROOT_DIR/script/build_app.sh" "$APP_PATH" >/dev/null

mkdir -p "$IMAGE_DIR"
ditto --norsrc --noextattr --noqtn --noacl "$APP_PATH" "$IMAGE_DIR/$APP_NAME.app"
ln -s /Applications "$IMAGE_DIR/Applications"

rm -f "$DMG_PATH"
codesign --verify --deep --strict "$APP_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$IMAGE_DIR" \
  -ov \
  -format UDZO \
  "$TEMP_DMG" >/dev/null
ditto --norsrc --noextattr --noqtn --noacl "$TEMP_DMG" "$DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null
LC_ALL=C LANG=C shasum -a 256 "$DMG_PATH"
