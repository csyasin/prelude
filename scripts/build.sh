#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/Prelude.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
rm -f \
    "$APP_DIR/Contents/Resources/default.toml" \
    "$APP_DIR/Contents/Resources/PreludeOrbit.icns" \
    "$APP_DIR/Contents/Resources/PreludePanels.icns" \
    "$APP_DIR/Contents/Resources/PreludeMenuOrbit.png" \
    "$APP_DIR/Contents/Resources/PreludeMenuPanels.png"
cp "$BIN_DIR/Prelude" "$APP_DIR/Contents/MacOS/Prelude"
cp "$PROJECT_DIR/Sources/Prelude/Resources/preluderc" "$APP_DIR/Contents/Resources/preluderc"
cp "$PROJECT_DIR/Sources/Prelude/Resources/PreludeMenuTemplate.png" "$APP_DIR/Contents/Resources/PreludeMenuTemplate.png"
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$APP_DIR/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Assets/Prelude.icns" "$APP_DIR/Contents/Resources/Prelude.icns"
codesign --force --deep --sign - "$APP_DIR"
echo "Built: $APP_DIR"
