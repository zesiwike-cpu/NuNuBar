#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
export LANG=C

APP_NAME="NuNuBar"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

DMG_PATH=""
RELEASE_REPO=""
RELEASE_TAG=""
RELEASE_ASSET=""
RELEASE_URL=""
EXPECTED_SHA256=""
ALLOW_UNNOTARIZED=0
SOURCE_IS_LOCAL=0
ASSET_NAME=""

usage() {
  cat <<'USAGE'
Usage:
  setup-macos.sh --dmg PATH --allow-unnotarized [--sha256 HEX]
  setup-macos.sh --release OWNER/REPO --asset FILE [--tag TAG] [--sha256 HEX]
  setup-macos.sh --release-url GITHUB_DMG_URL [--sha256 HEX] [--allow-unnotarized]

Options:
  --dmg PATH          Install from a local DMG.
  --release REPO      Download from a GitHub repository such as owner/project.
  --tag TAG           Exact release tag. Without it, use releases/latest.
  --asset FILE        Exact DMG asset filename in the GitHub release.
  --release-url URL   Direct github.com release DMG URL.
  --sha256 HEX        Optional expected SHA-256 for the DMG.
  --allow-unnotarized Explicitly allow a local or UNNOTARIZED development DMG.
                       A second interactive confirmation is still required.
  -h, --help          Show this help.

This script installs NuNuBar.app only. It never flashes keyboard firmware,
enters DFU, edits Codex Hooks, registers startup, or launches the app.
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --dmg)
      (($# >= 2)) || die "--dmg requires a path"
      DMG_PATH="$2"
      shift 2
      ;;
    --release)
      (($# >= 2)) || die "--release requires OWNER/REPO"
      RELEASE_REPO="$2"
      shift 2
      ;;
    --tag)
      (($# >= 2)) || die "--tag requires a value"
      RELEASE_TAG="$2"
      shift 2
      ;;
    --asset)
      (($# >= 2)) || die "--asset requires a filename"
      RELEASE_ASSET="$2"
      shift 2
      ;;
    --release-url)
      (($# >= 2)) || die "--release-url requires a URL"
      RELEASE_URL="$2"
      shift 2
      ;;
    --sha256)
      (($# >= 2)) || die "--sha256 requires a hex digest"
      EXPECTED_SHA256="$2"
      shift 2
      ;;
    --allow-unnotarized)
      ALLOW_UNNOTARIZED=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "this installer runs on macOS only"

source_count=0
[[ -n "$DMG_PATH" ]] && ((source_count += 1))
[[ -n "$RELEASE_REPO" ]] && ((source_count += 1))
[[ -n "$RELEASE_URL" ]] && ((source_count += 1))
((source_count == 1)) || die "choose exactly one source: --dmg, --release, or --release-url"

if [[ -n "$RELEASE_REPO" ]]; then
  [[ "$RELEASE_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "invalid GitHub OWNER/REPO"
  [[ -n "$RELEASE_ASSET" ]] || die "--release requires --asset"
  [[ "$RELEASE_ASSET" == *.dmg ]] || die "the release asset must be a DMG"
  [[ "$RELEASE_ASSET" != */* ]] || die "--asset must be a filename, not a path"
  ASSET_NAME="$RELEASE_ASSET"
  if [[ -n "$RELEASE_TAG" ]]; then
    RELEASE_URL="https://github.com/$RELEASE_REPO/releases/download/$RELEASE_TAG/$RELEASE_ASSET"
  else
    RELEASE_URL="https://github.com/$RELEASE_REPO/releases/latest/download/$RELEASE_ASSET"
  fi
fi

if [[ -n "$RELEASE_URL" ]]; then
  case "$RELEASE_URL" in
    https://github.com/*/releases/download/*.dmg|https://github.com/*/releases/latest/download/*.dmg) ;;
    *) die "--release-url must be an HTTPS github.com release DMG URL" ;;
  esac
  [[ -n "$ASSET_NAME" ]] || ASSET_NAME="$(basename "$RELEASE_URL")"
else
  SOURCE_IS_LOCAL=1
fi

DEVELOPMENT_BUILD=0
ASSET_NAME_LOWER="$(printf '%s' "$ASSET_NAME" | tr '[:upper:]' '[:lower:]')"
if ((SOURCE_IS_LOCAL)) || [[ "$ASSET_NAME_LOWER" == *unnotarized* ]]; then
  DEVELOPMENT_BUILD=1
fi
if ((DEVELOPMENT_BUILD)); then
  ((ALLOW_UNNOTARIZED)) || die "local and UNNOTARIZED DMGs require --allow-unnotarized"
else
  ((ALLOW_UNNOTARIZED == 0)) || die "--allow-unnotarized is only valid for local or UNNOTARIZED development DMGs"
fi

if [[ -n "$EXPECTED_SHA256" ]]; then
  EXPECTED_SHA256="$(printf '%s' "$EXPECTED_SHA256" | tr '[:upper:]' '[:lower:]')"
  [[ "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "--sha256 must contain exactly 64 hexadecimal characters"
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nunubar-setup.XXXXXX")"
MOUNT_DIR="$TEMP_DIR/mount"
MOUNTED=0
mkdir -p "$MOUNT_DIR"

cleanup() {
  if ((MOUNTED)); then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [[ -n "$RELEASE_URL" ]]; then
  DMG_PATH="$TEMP_DIR/$APP_NAME.dmg"
  printf 'Downloading %s\n' "$RELEASE_URL"
  curl --fail --location --proto '=https' --tlsv1.2 --output "$DMG_PATH" "$RELEASE_URL"
  quarantine_stamp="$(printf '%x' "$(date +%s)")"
  xattr -w com.apple.quarantine "0081;$quarantine_stamp;NuNuBar;" "$DMG_PATH"
else
  [[ -f "$DMG_PATH" ]] || die "DMG not found: $DMG_PATH"
  DMG_PATH="$(cd "$(dirname "$DMG_PATH")" && pwd)/$(basename "$DMG_PATH")"
fi

ACTUAL_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print tolower($1)}')"
if [[ -n "$EXPECTED_SHA256" && "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  die "SHA-256 mismatch: expected $EXPECTED_SHA256, got $ACTUAL_SHA256"
fi
printf 'DMG SHA-256: %s\n' "$ACTUAL_SHA256"

if ((DEVELOPMENT_BUILD)); then
  cat >&2 <<'WARNING'

WARNING: this is a local or explicitly UNNOTARIZED development build.
It is not being presented as Apple-notarized or Gatekeeper-ready. Installing
it keeps quarantine metadata and may cause macOS to block it at launch.
Type UNNOTARIZED to confirm this development installation, or anything else
to cancel.
WARNING
  read -r development_confirmation
  [[ "$development_confirmation" == "UNNOTARIZED" ]] || die "development installation cancelled"
else
  printf 'Assessing the release DMG with Gatekeeper...\n'
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
fi

hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_DIR" "$DMG_PATH" >/dev/null
MOUNTED=1

SOURCE_APP="$MOUNT_DIR/$APP_NAME.app"
[[ -d "$SOURCE_APP" ]] || die "$APP_NAME.app is missing from the DMG root"
[[ ! -L "$SOURCE_APP" ]] || die "refusing a symlinked app bundle"
codesign --verify --deep --strict "$SOURCE_APP"
if ((DEVELOPMENT_BUILD)); then
  if spctl --assess --type execute --verbose=2 "$SOURCE_APP"; then
    printf 'Gatekeeper accepted the app, but it remains classified as a development build because of its source/name.\n'
  else
    printf 'Gatekeeper did not accept this development app; continuing only because --allow-unnotarized was confirmed.\n' >&2
  fi
else
  printf 'Assessing the release app with Gatekeeper...\n'
  spctl --assess --type execute --verbose=2 "$SOURCE_APP"
fi

APP_EXECUTABLE="$SOURCE_APP/Contents/MacOS/$APP_NAME"
[[ -x "$APP_EXECUTABLE" ]] || die "the app executable is missing"
HOST_ARCH="$(uname -m)"
APP_ARCHES="$(lipo -archs "$APP_EXECUTABLE")"
case " $APP_ARCHES " in
  *" $HOST_ARCH "*) ;;
  *) die "the app supports [$APP_ARCHES], not this Mac architecture [$HOST_ARCH]" ;;
esac

mkdir -p "$INSTALL_DIR"
DESTINATION="$INSTALL_DIR/$APP_NAME.app"
if [[ -L "$DESTINATION" ]]; then
  die "refusing to replace symlink: $DESTINATION"
fi
if [[ -e "$DESTINATION" ]]; then
  printf '%s already exists. Replace it after making a temporary rollback copy? [y/N] ' "$DESTINATION" >&2
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) die "installation cancelled; the existing app was not changed" ;;
  esac
fi

USE_SUDO=0
if [[ ! -w "$INSTALL_DIR" ]]; then
  printf 'Administrator permission is required to write %s.\n' "$INSTALL_DIR" >&2
  sudo -v
  USE_SUDO=1
fi

run_admin() {
  if ((USE_SUDO)); then
    sudo "$@"
  else
    "$@"
  fi
}

STAGED_APP="$INSTALL_DIR/.$APP_NAME.app.install.$$"
BACKUP_APP="$INSTALL_DIR/.$APP_NAME.app.rollback.$$"
run_admin rm -rf "$STAGED_APP" "$BACKUP_APP"
run_admin ditto --rsrc --extattr --qtn --acl "$SOURCE_APP" "$STAGED_APP"

if ! run_admin xattr -p com.apple.quarantine "$STAGED_APP" >/dev/null 2>&1; then
  quarantine_stamp="$(printf '%x' "$(date +%s)")"
  run_admin xattr -w com.apple.quarantine "0081;$quarantine_stamp;NuNuBar;" "$STAGED_APP"
fi

if [[ -e "$DESTINATION" ]]; then
  run_admin mv "$DESTINATION" "$BACKUP_APP"
fi

if ! run_admin mv "$STAGED_APP" "$DESTINATION"; then
  if [[ -e "$BACKUP_APP" ]]; then
    run_admin mv "$BACKUP_APP" "$DESTINATION" || true
  fi
  die "installation failed; rollback was attempted"
fi

if ! codesign --verify --deep --strict "$DESTINATION"; then
  run_admin rm -rf "$DESTINATION"
  if [[ -e "$BACKUP_APP" ]]; then
    run_admin mv "$BACKUP_APP" "$DESTINATION"
  fi
  die "installed app signature verification failed; the previous app was restored"
fi
if ! run_admin xattr -p com.apple.quarantine "$DESTINATION" >/dev/null 2>&1; then
  run_admin rm -rf "$DESTINATION"
  if [[ -e "$BACKUP_APP" ]]; then
    run_admin mv "$BACKUP_APP" "$DESTINATION"
  fi
  die "installed app lost quarantine metadata; the previous app was restored"
fi

run_admin rm -rf "$BACKUP_APP"

printf '\nInstalled: %s\n' "$DESTINATION"
if ((DEVELOPMENT_BUILD)); then
  printf 'Build trust: DEVELOPMENT / UNNOTARIZED override (quarantine preserved).\n'
else
  printf 'Build trust: Gatekeeper assessment passed for the release DMG and app (quarantine preserved).\n'
fi
printf 'No firmware was flashed. DFU was not entered. Codex Hooks and user configuration were not changed.\n'
printf 'Launch NuNuBar manually when you are ready to continue setup.\n'
