#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-small37/cx}"
VERSION="${2:-latest}"
INSTALL_DIR="${CX_INSTALL_DIR:-$HOME/.local/bin}"

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *)
      echo "Unsupported OS: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64) echo "amd64" ;;
    *)
      echo "Unsupported arch: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

OS="$(detect_os)"
ARCH="$(detect_arch)"
ASSET="cx_${OS}_${ARCH}.tar.gz"

if [ "$VERSION" = "latest" ]; then
  URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
else
  URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

mkdir -p "$INSTALL_DIR"

echo "Downloading: $URL"
curl -fL "$URL" -o "$TMP_DIR/$ASSET"

echo "Extracting package..."
tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR"

if [ -x "$TMP_DIR/cx" ]; then
  BIN_PATH="$TMP_DIR/cx"
elif [ -x "$TMP_DIR/bin/cx" ]; then
  BIN_PATH="$TMP_DIR/bin/cx"
else
  echo "Binary cx not found in package: $ASSET" >&2
  exit 1
fi

install -m 0755 "$BIN_PATH" "$INSTALL_DIR/cx"

echo
echo "Installed: $INSTALL_DIR/cx"
echo "Run: cx --help"
echo "If command not found, add PATH:"
echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
