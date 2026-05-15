#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-https://github.com/small37/codex.git}"
INSTALL_ROOT="${HOME}/.touchbar-island"
SRC_DIR="${INSTALL_ROOT}/src"
TARGET_DIR="${SRC_DIR}/touchbar-island"

mkdir -p "$SRC_DIR"

if [ -d "$TARGET_DIR/.git" ]; then
  echo "Updating existing source: $TARGET_DIR"
  git -C "$TARGET_DIR" fetch --depth=1 origin
  git -C "$TARGET_DIR" reset --hard origin/main
else
  echo "Cloning source from: $REPO_URL"
  rm -rf "$TARGET_DIR"
  git clone --depth=1 "$REPO_URL" "$TARGET_DIR"
fi

echo "Building app and helper binaries..."
cd "$TARGET_DIR/demo"
./build.sh

echo "Installing command tools..."
cd "$TARGET_DIR/demo/scripts"
./install_commands.sh

echo
echo "Install completed."
echo "Run app: open /Applications/SleepGuardDemo.app"
echo "Test commands:"
echo "  tbmsg \"hermes 任务开始\""
echo "  tbdone \"任务结束\""
