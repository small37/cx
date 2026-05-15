#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-https://github.com/small37/cx.git}"
INSTALL_ROOT="${HOME}/.cx"
SRC_DIR="${INSTALL_ROOT}/src"
TARGET_DIR="${SRC_DIR}/cx"

mkdir -p "$SRC_DIR"

if [ -d "$TARGET_DIR/.git" ]; then
  echo "Updating source: $TARGET_DIR"
  git -C "$TARGET_DIR" fetch --depth=1 origin
  git -C "$TARGET_DIR" reset --hard origin/main
else
  echo "Cloning source: $REPO_URL"
  rm -rf "$TARGET_DIR"
  git clone --depth=1 "$REPO_URL" "$TARGET_DIR"
fi

echo "Installing cx binary..."
cd "$TARGET_DIR"
go install ./cmd/cx

echo
echo "Install done."
echo "Binary path: $(go env GOPATH)/bin/cx"
echo "Optional zsh integration:"
echo "  source \"$TARGET_DIR/integrations/cx.zsh\""
