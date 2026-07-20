#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NuNuBar"
PRODUCT_NAME="NuNuBar"
BUNDLE_ID="com.maige.NuphyBar"
APP_VERSION="${APP_VERSION:-0.15.0}"
BUILD_VERSION="${BUILD_VERSION:-54}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
MIN_SYSTEM_VERSION="14.0"
DESIGNATED_REQUIREMENT="designated => identifier \"$BUNDLE_ID\""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_APP="${1:-$ROOT_DIR/dist/$APP_NAME.app}"

if [ "$(basename "$OUTPUT_APP")" != "$APP_NAME.app" ]; then
  echo "output must end in $APP_NAME.app" >&2
  exit 2
fi

APP_CONTENTS="$OUTPUT_APP/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_HELPERS="$APP_CONTENTS/Helpers"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
DFU_UTIL_SOURCE="${DFU_UTIL_PATH:-$(command -v dfu-util || true)}"
LIBUSB_SOURCE="${LIBUSB_PATH:-/opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib}"

if [ -z "$DFU_UTIL_SOURCE" ] || [ ! -x "$DFU_UTIL_SOURCE" ]; then
  echo "dfu-util is required to build the self-contained app" >&2
  exit 3
fi
if [ ! -f "$LIBUSB_SOURCE" ]; then
  echo "libusb-1.0.0.dylib is required to build the self-contained app" >&2
  exit 3
fi
for code_path in "$DFU_UTIL_SOURCE" "$LIBUSB_SOURCE"; do
  if ! file "$code_path" | grep -q "arm64"; then
    echo "$code_path must contain arm64 code" >&2
    exit 3
  fi
done

cd "$ROOT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$OUTPUT_APP"
mkdir -p "$APP_MACOS" "$APP_HELPERS" "$APP_FRAMEWORKS" "$APP_RESOURCES"
cp "$BIN_DIR/$PRODUCT_NAME" "$APP_BINARY"
cp "$BIN_DIR/agent-light" "$APP_HELPERS/agent-light"
cp "$DFU_UTIL_SOURCE" "$APP_HELPERS/dfu-util"
cp "$LIBUSB_SOURCE" "$APP_FRAMEWORKS/libusb-1.0.0.dylib"
chmod u+w "$APP_HELPERS/dfu-util" "$APP_FRAMEWORKS/libusb-1.0.0.dylib"
cp "$ROOT_DIR/Sources/AgentLightApp/Resources/NuNuBar.icns" "$APP_RESOURCES/NuNuBar.icns"
cp "$ROOT_DIR/Sources/AgentLightApp/Resources/NuNuBarMenuBarIcon.png" "$APP_RESOURCES/NuNuBarMenuBarIcon.png"
cp -R "$ROOT_DIR/Sources/AgentLightApp/Resources/Firmware" "$APP_RESOURCES/Firmware"
cp -R "$ROOT_DIR/Sources/AgentLightApp/Resources/Licenses" "$APP_RESOURCES/Licenses"
mkdir -p "$APP_RESOURCES/Licenses/FirmwareSource"
cp -R "$ROOT_DIR/firmware/." "$APP_RESOURCES/Licenses/FirmwareSource/"

for asset in Codex.png ClaudeCode.png Antigravity.png GrokBuild.svg Hermes.png OpenClaw.png; do
  cp "$ROOT_DIR/Sources/AgentLightApp/Resources/AgentIcons/$asset" "$APP_RESOURCES/$asset"
done

LIBUSB_LINK="$(otool -L "$APP_HELPERS/dfu-util" | awk '/libusb-1.0.0.dylib/{print $1; exit}')"
if [ -z "$LIBUSB_LINK" ]; then
  echo "could not locate the dfu-util libusb dependency" >&2
  exit 3
fi
install_name_tool -id @rpath/libusb-1.0.0.dylib "$APP_FRAMEWORKS/libusb-1.0.0.dylib"
install_name_tool \
  -change "$LIBUSB_LINK" \
  @rpath/libusb-1.0.0.dylib \
  "$APP_HELPERS/dfu-util"
install_name_tool \
  -add_rpath @executable_path/../Frameworks \
  "$APP_HELPERS/dfu-util"

chmod +x "$APP_BINARY" "$APP_HELPERS/agent-light" "$APP_HELPERS/dfu-util"
strip -x \
  "$APP_BINARY" \
  "$APP_HELPERS/agent-light" \
  "$APP_HELPERS/dfu-util" \
  "$APP_FRAMEWORKS/libusb-1.0.0.dylib"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>NuNuBar</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSInputMonitoringUsageDescription</key>
  <string>NuNuBar sends status to compatible NuPhy keyboards over Bluetooth or USB. It never reads or stores keystrokes.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP_FRAMEWORKS/libusb-1.0.0.dylib"
  codesign --force --sign - "$APP_HELPERS/agent-light"
  codesign --force --sign - "$APP_HELPERS/dfu-util"
  codesign --force --sign - --requirements "=$DESIGNATED_REQUIREMENT" "$OUTPUT_APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_FRAMEWORKS/libusb-1.0.0.dylib"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_HELPERS/agent-light"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_HELPERS/dfu-util"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$OUTPUT_APP"
fi
codesign --verify --deep --strict "$OUTPUT_APP"

echo "$OUTPUT_APP"
