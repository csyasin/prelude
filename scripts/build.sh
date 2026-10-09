#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
APP_ENABLE_UPDATES="${APP_ENABLE_UPDATES:-0}"
if [[ "$APP_ENABLE_UPDATES" != 0 && "$APP_ENABLE_UPDATES" != 1 ]]; then
    echo "APP_ENABLE_UPDATES must be 0 (development) or 1 (distribution)." >&2
    exit 2
fi
if [[ "$APP_ENABLE_UPDATES" == 1 ]]; then
    python3 - <<'PY'
import base64, plistlib
info = plistlib.load(open('Info.plist', 'rb'))
if len(base64.b64decode(info.get('SUPublicEDKey', ''), validate=True)) != 32:
    raise SystemExit('Configure the update signing key with scripts/setup-updates.py first.')
PY
fi
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
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"
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
if [[ "$APP_ENABLE_UPDATES" == 1 ]]; then
    /usr/libexec/PlistBuddy -c 'Set :PreludeUpdatesEnabled true' "$APP_DIR/Contents/Info.plist"
else
    /usr/libexec/PlistBuddy -c 'Set :PreludeUpdatesEnabled false' "$APP_DIR/Contents/Info.plist"
fi
cp "$PROJECT_DIR/Assets/Prelude.icns" "$APP_DIR/Contents/Resources/Prelude.icns"
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$APP_DIR/Contents/Resources/THIRD_PARTY_NOTICES.md"
SPARKLE_FRAMEWORK="$APP_DIR/Contents/Frameworks/Sparkle.framework"
rm -rf "$SPARKLE_FRAMEWORK"
ditto "$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$SPARKLE_FRAMEWORK"
# This app is not sandboxed; Sparkle's optional XPC services are not used.
rm -rf "$SPARKLE_FRAMEWORK/Versions/B/XPCServices"
codesign --force --sign - "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate"
codesign --force --sign - "$SPARKLE_FRAMEWORK/Versions/B/Updater.app"
codesign --force --sign - "$SPARKLE_FRAMEWORK"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built: $APP_DIR"
echo "Version: $APP_VERSION (build $APP_BUILD_NUMBER)"
echo "Updates enabled: $APP_ENABLE_UPDATES"
