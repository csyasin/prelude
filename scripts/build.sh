#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
APP_VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)}"
if [[ ! "$APP_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "APP_VERSION must use X.Y.Z format without leading zeros." >&2
    exit 2
fi
if [[ -z "${APP_BUILD_NUMBER:-}" ]]; then
    if [[ -n "${GITHUB_RUN_NUMBER:-}" ]]; then
        APP_BUILD_NUMBER="$GITHUB_RUN_NUMBER.${GITHUB_RUN_ATTEMPT:-1}"
    elif LOCAL_COMMIT_COUNT="$(git rev-list --count HEAD 2>/dev/null)"; then
        APP_BUILD_NUMBER="$LOCAL_COMMIT_COUNT.0"
    else
        APP_BUILD_NUMBER="1.0"
    fi
fi
if [[ ! "$APP_BUILD_NUMBER" =~ ^[1-9][0-9]*(\.(0|[1-9][0-9]*)){0,2}$ ]]; then
    echo "APP_BUILD_NUMBER must contain one to three integers, with a positive first integer." >&2
    exit 2
fi
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/Prelude.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
rm -f \
    "$APP_DIR/Contents/Resources/THIRD_PARTY_NOTICES.md" \
    "$APP_DIR/Contents/Resources/default.toml" \
    "$APP_DIR/Contents/Resources/PreludeOrbit.icns" \
    "$APP_DIR/Contents/Resources/PreludePanels.icns" \
    "$APP_DIR/Contents/Resources/PreludeMenuOrbit.png" \
    "$APP_DIR/Contents/Resources/PreludeMenuPanels.png"
cp "$BIN_DIR/Prelude" "$APP_DIR/Contents/MacOS/Prelude"
cp "$PROJECT_DIR/Sources/Prelude/Resources/preluderc" "$APP_DIR/Contents/Resources/preluderc"
cp "$PROJECT_DIR/Sources/Prelude/Resources/PreludeMenuTemplate.png" "$APP_DIR/Contents/Resources/PreludeMenuTemplate.png"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Assets/Prelude.icns" "$APP_DIR/Contents/Resources/Prelude.icns"
codesign --force --deep --sign - "$APP_DIR"
echo "Built: $APP_DIR"
echo "Version: $APP_VERSION (build $APP_BUILD_NUMBER)"
