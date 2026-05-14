#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
FONT_SRC_DIR="$ROOT_DIR/Resources/Fonts"
APP_NAME="SleepGuardDemo"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
INSTALL_APP_DIR="/Applications/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
APP_FONT_DIR="$RESOURCES_DIR/Fonts"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"

swiftc \
  "$ROOT_DIR/src/HotkeyManager.swift" \
  "$ROOT_DIR/src/AppConfig.swift" \
  "$ROOT_DIR/src/HotkeyConfig.swift" \
  "$ROOT_DIR/src/SelectedTextReader.swift" \
  "$ROOT_DIR/src/AXSelectedTextReader.swift" \
  "$ROOT_DIR/src/PasteboardBackup.swift" \
  "$ROOT_DIR/src/ClipboardTextReader.swift" \
  "$ROOT_DIR/src/BaiduTranslator.swift" \
  "$ROOT_DIR/src/OfflineOCR.swift" \
  "$ROOT_DIR/src/FloatingTextPanel.swift" \
  "$ROOT_DIR/src/ToastWindow.swift" \
  "$ROOT_DIR/src/DateFileName.swift" \
  "$ROOT_DIR/src/ScreenshotManager.swift" \
  "$ROOT_DIR/src/PermissionManager.swift" \
  "$ROOT_DIR/src/SleepManager.swift" \
  "$ROOT_DIR/src/TouchBarMessage.swift" \
  "$ROOT_DIR/src/LayoutNode.swift" \
  "$ROOT_DIR/src/LayoutParser.swift" \
  "$ROOT_DIR/src/FontManager.swift" \
  "$ROOT_DIR/src/CurrentMessageStore.swift" \
  "$ROOT_DIR/src/CommandRouter.swift" \
  "$ROOT_DIR/src/SocketServer.swift" \
  "$ROOT_DIR/src/TouchBarController.swift" \
  "$ROOT_DIR/src/StatusBarController.swift" \
  "$ROOT_DIR/src/AppDelegate.swift" \
  "$ROOT_DIR/src/main.swift" \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices \
  -framework IOKit \
  -framework Vision \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

if [ -d "$FONT_SRC_DIR" ]; then
  mkdir -p "$APP_FONT_DIR"
  cp "$FONT_SRC_DIR"/* "$APP_FONT_DIR"/ 2>/dev/null || true
fi

codesign --force --deep --sign - "$APP_DIR"
ditto "$APP_DIR" "$INSTALL_APP_DIR"
codesign --force --deep --sign - "$INSTALL_APP_DIR"

swiftc \
  "$ROOT_DIR/src/SleepManager.swift" \
  "$ROOT_DIR/src/assertion_tester.swift" \
  -framework IOKit \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -o "$BUILD_DIR/assertion_tester"

swiftc \
  "$ROOT_DIR/src/socket_sender.swift" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -o "$BUILD_DIR/tbsend_swift"

echo "Build done:"
echo "  App: $APP_DIR"
echo "  Installed App: $INSTALL_APP_DIR"
echo "  CLI: $BUILD_DIR/assertion_tester"
echo "  Sender: $BUILD_DIR/tbsend_swift"
