#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"

cd "$PACKAGE_ROOT"

swift build -c "$CONFIGURATION"

BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BUILD_DIR="${BUILD_DIR:-$BIN_PATH}"
APP_PATH="$BUILD_DIR/DesktopPet.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
EXECUTABLE_PATH="$BIN_PATH/DesktopPet"
RESOURCE_BUNDLE_PATH="$BIN_PATH/DesktopPet_DesktopPetApp.bundle"

rm -rf "$APP_PATH"
mkdir -p "$MACOS_PATH" "$RESOURCES_PATH"

cp "$EXECUTABLE_PATH" "$MACOS_PATH/DesktopPet"
cp "$PACKAGE_ROOT/Packaging/DesktopPet-Info.plist" "$CONTENTS_PATH/Info.plist"
cp "$PACKAGE_ROOT/Sources/DesktopPetApp/Resources/DesktopPetIcon.icns" "$RESOURCES_PATH/DesktopPetIcon.icns"

if [[ -d "$RESOURCE_BUNDLE_PATH" ]]; then
    cp -R "$RESOURCE_BUNDLE_PATH" "$RESOURCES_PATH/"
fi

echo "$APP_PATH"
