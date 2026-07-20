#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCE_DIR="$ROOT_DIR/Sources/AgentLightApp/Resources"
STAGE_DIR="$(mktemp -d /tmp/NuNuBar-icons.XXXXXX)"
ICONSET_DIR="$STAGE_DIR/NuNuBar.iconset"
SOURCE_PNG="$ROOT_DIR/Design/NuNuBarAppIcon-v2.png"
trap 'rm -rf "$STAGE_DIR"' EXIT

mkdir -p "$RESOURCE_DIR" "$ICONSET_DIR"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCE_DIR/NuNuBar.icns"

MENU_BAR_ICON="$RESOURCE_DIR/NuNuBarMenuBarIcon.png"
if [[ ! -f "$MENU_BAR_ICON" ]]; then
  echo "missing menu bar icon: $MENU_BAR_ICON" >&2
  exit 1
fi
