#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
BIN_NAME="cx"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR"/cx_*.tar.gz "$DIST_DIR/$BIN_NAME"

build_one() {
  local os="$1"
  local arch="$2"
  local out="${DIST_DIR}/cx_${os}_${arch}.tar.gz"
  GOOS="$os" GOARCH="$arch" CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o "${DIST_DIR}/${BIN_NAME}" "${ROOT_DIR}/cmd/cx"
  tar -C "$DIST_DIR" -czf "$out" "$BIN_NAME"
  rm -f "${DIST_DIR}/${BIN_NAME}"
  echo "built: $out"
}

build_one darwin amd64
build_one darwin arm64
build_one linux amd64
build_one linux arm64

echo "done: ${DIST_DIR}"
