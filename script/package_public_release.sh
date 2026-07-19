#!/usr/bin/env bash
set -euo pipefail

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to a Developer ID Application certificate name}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an xcrun notarytool keychain profile}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="${APP_VERSION:-0.13.1}"
DMG_PATH="$ROOT_DIR/dist/NuNuBar-$APP_VERSION-macOS-arm64.dmg"

SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
APP_VERSION="$APP_VERSION" \
"$ROOT_DIR/script/package_release.sh"

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
LC_ALL=C LANG=C shasum -a 256 "$DMG_PATH"
