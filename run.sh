#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [platform] [options]

Platforms:
  macos        Build and run on macOS
  ios          Build and run on iOS Simulator
  (default)    Auto-detected from project SDKROOT

Options:
  --device     iOS only: install and run on a connected iPhone
  --open       macOS only: launch via 'open' for proper bundle identity
  -h, --help   Show this help

Examples:
  $(basename "$0")                # auto-detect platform
  $(basename "$0") macos --open
  $(basename "$0") ios
  $(basename "$0") ios --device
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
UUID_RE='[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'

PROJECT=$(ls -d "$ROOT_DIR"/*.xcodeproj 2>/dev/null | head -1)
if [[ -z "${PROJECT:-}" ]]; then
  echo "error: no .xcodeproj found in $ROOT_DIR" >&2
  exit 1
fi
APP_NAME=$(basename "$PROJECT" .xcodeproj)
BUNDLE_ID=$(grep -m1 PRODUCT_BUNDLE_IDENTIFIER "$PROJECT/project.pbxproj" \
  | sed 's/.*= //;s/;.*//;s/"//g' | tr -d '[:space:]')
DERIVED_GLOB="${APP_NAME// /_}-*"

DEFAULT_SDK=$(grep -m1 -E '^\s*SDKROOT' "$PROJECT/project.pbxproj" \
  | sed 's/.*= //;s/;.*//;s/"//g' | tr -d '[:space:]')
case "$DEFAULT_SDK" in
  macosx)   PLATFORM="macos" ;;
  iphoneos) PLATFORM="ios" ;;
  *)        PLATFORM="macos" ;;
esac

USE_DEVICE=0
MAC_MODE="run"

while [[ $# -gt 0 ]]; do
  case "$1" in
    macos|mac)   PLATFORM="macos" ;;
    ios)         PLATFORM="ios" ;;
    --device)    USE_DEVICE=1; PLATFORM="ios" ;;
    --open)      MAC_MODE="open" ;;
    -h|--help)   usage; exit 0 ;;
    *)           echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

find_app_bundle() {
  local subdir="$1"
  local bundle
  bundle=$(ls -dt "$DERIVED_DATA"/$DERIVED_GLOB/Build/Products/"$subdir"/"$APP_NAME.app" 2>/dev/null | head -1)
  if [[ -z "$bundle" || ! -d "$bundle" ]]; then
    echo "error: built app not found at $DERIVED_DATA/$DERIVED_GLOB/Build/Products/$subdir/$APP_NAME.app" >&2
    exit 1
  fi
  echo "$bundle"
}

run_macos() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "platform=macOS" \
    -quiet \
    build

  local APP_BUNDLE APP_BIN APP_PID
  APP_BUNDLE=$(find_app_bundle "Debug")
  APP_BIN="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

  if [[ "$MAC_MODE" == "open" ]]; then
    open -W "$APP_BUNDLE" &
  else
    "$APP_BIN" &
  fi
  APP_PID=$!
  trap 'kill $APP_PID 2>/dev/null || true' EXIT
  wait $APP_PID
}

run_ios_device() {
  local DEVICE_ID
  DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null \
    | awk '!/unavailable/ && /iPhone/ && /available/' \
    | grep -oE "$UUID_RE" \
    | head -1)
  if [[ -z "${DEVICE_ID:-}" ]]; then
    echo "error: no available iPhone device found" >&2
    exit 1
  fi
  echo "Using device: $DEVICE_ID"

  xcrun devicectl device process terminate \
    --device "$DEVICE_ID" --bundle-identifier "$BUNDLE_ID" >/dev/null 2>&1 || true

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "id=$DEVICE_ID" \
    -quiet \
    build

  local APP_BUNDLE LAUNCH_PID
  APP_BUNDLE=$(find_app_bundle "Debug-iphoneos")
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_BUNDLE"

  xcrun devicectl device process launch --console --device "$DEVICE_ID" "$BUNDLE_ID" &
  LAUNCH_PID=$!
  trap "kill \$LAUNCH_PID 2>/dev/null || true; xcrun devicectl device process terminate --device '$DEVICE_ID' --bundle-identifier '$BUNDLE_ID' >/dev/null 2>&1 || true" EXIT
  wait $LAUNCH_PID
}

run_ios_simulator() {
  local SIM_ID
  SIM_ID=$(xcrun simctl list devices available \
    | grep -E "iPhone.* Pro \(" \
    | head -1 \
    | grep -oE "$UUID_RE")
  if [[ -z "${SIM_ID:-}" ]]; then
    echo "error: no iPhone Pro simulator found" >&2
    exit 1
  fi
  echo "Using simulator: $SIM_ID"

  xcrun simctl boot "$SIM_ID" 2>/dev/null || true
  open -g -a Simulator

  xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    -quiet \
    build

  local APP_BUNDLE LAUNCH_PID
  APP_BUNDLE=$(find_app_bundle "Debug-iphonesimulator")
  xcrun simctl install "$SIM_ID" "$APP_BUNDLE"
  open -a Simulator

  xcrun simctl launch --console-pty --terminate-running-process "$SIM_ID" "$BUNDLE_ID" &
  LAUNCH_PID=$!
  trap "kill \$LAUNCH_PID 2>/dev/null || true; xcrun simctl terminate '$SIM_ID' '$BUNDLE_ID' >/dev/null 2>&1 || true" EXIT
  wait $LAUNCH_PID
}

case "$PLATFORM" in
  macos) run_macos ;;
  ios)
    if [[ "$USE_DEVICE" == "1" ]]; then
      run_ios_device
    else
      run_ios_simulator
    fi
    ;;
  *) echo "error: unknown platform '$PLATFORM'" >&2; exit 2 ;;
esac
