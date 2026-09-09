#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/Prelude.app"
rm -f "$APP_DIR/Contents/Resources/default.toml"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/Prelude" "$APP_DIR/Contents/MacOS/Prelude"
cp "$PROJECT_DIR/Sources/Prelude/Resources/preluderc" "$APP_DIR/Contents/Resources/preluderc"
if [ -f "$PROJECT_DIR/Sources/Prelude/Resources/PreludeMenuTemplate.png" ]; then
    cp "$PROJECT_DIR/Sources/Prelude/Resources/PreludeMenuTemplate.png" "$APP_DIR/Contents/Resources/PreludeMenuTemplate.png"
fi
for menu_icon in PreludeMenuOrbit.png PreludeMenuPanels.png; do
    if [ -f "$PROJECT_DIR/Sources/Prelude/Resources/$menu_icon" ]; then
        cp "$PROJECT_DIR/Sources/Prelude/Resources/$menu_icon" "$APP_DIR/Contents/Resources/$menu_icon"
    fi
done
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$APP_DIR/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ -f "$PROJECT_DIR/Assets/Prelude.icns" ]; then
    cp "$PROJECT_DIR/Assets/Prelude.icns" "$APP_DIR/Contents/Resources/Prelude.icns"
fi
for app_icon in PreludeOrbit.icns PreludePanels.icns; do
    if [ -f "$PROJECT_DIR/Assets/$app_icon" ]; then
        cp "$PROJECT_DIR/Assets/$app_icon" "$APP_DIR/Contents/Resources/$app_icon"
    fi
done
codesign --force --deep --sign - "$APP_DIR"
echo "Built: $APP_DIR"
