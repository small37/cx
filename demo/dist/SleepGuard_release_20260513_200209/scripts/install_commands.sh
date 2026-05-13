#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${HOME}/.touchbar-island/bin"
BUILD_DIR="$(cd "$ROOT_DIR/.." && pwd)/build"

mkdir -p "$TARGET_DIR"
cp "$ROOT_DIR"/tb* "$TARGET_DIR"/
chmod +x "$TARGET_DIR"/tb*

if [ -x "$BUILD_DIR/tbsend_swift" ]; then
  cp "$BUILD_DIR/tbsend_swift" "$TARGET_DIR/tbsend_swift"
  chmod +x "$TARGET_DIR/tbsend_swift"
fi

if [ -f "$ROOT_DIR/benchmark_resources.sh" ]; then
  chmod +x "$ROOT_DIR/benchmark_resources.sh"
fi
if [ -f "$ROOT_DIR/release_check.sh" ]; then
  chmod +x "$ROOT_DIR/release_check.sh"
fi
if [ -f "$ROOT_DIR/merge_claude_hooks.sh" ]; then
  chmod +x "$ROOT_DIR/merge_claude_hooks.sh"
fi
if [ -f "$ROOT_DIR/package_release.sh" ]; then
  chmod +x "$ROOT_DIR/package_release.sh"
fi

echo "Installed commands to: $TARGET_DIR"
echo "Ensure PATH contains: $TARGET_DIR"
echo
echo "Optional: install Claude hooks template"
echo "  $ROOT_DIR/install_claude_hooks.sh"
echo "Optional: merge hooks into your target config"
echo "  $ROOT_DIR/merge_claude_hooks.sh /path/to/hooks.json"
echo "Optional: release checks"
echo "  $ROOT_DIR/release_check.sh"
echo "Optional: build distributable package"
echo "  $ROOT_DIR/package_release.sh"
