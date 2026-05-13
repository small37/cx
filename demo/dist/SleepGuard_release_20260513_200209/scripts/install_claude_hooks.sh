#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
SRC="$PROJECT_ROOT/docs/claude_hooks.touchbar.example.json"
DEST_DIR="$HOME/.touchbar-island"
DEST="$DEST_DIR/claude_hooks.json"

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST"

echo "Installed hook template:"
echo "  $DEST"
echo
echo "Next:"
echo "1) Merge this JSON into your Claude hooks config."
echo "2) Keep command paths as:"
echo "   $HOME/.touchbar-island/bin/tbmsg"
echo "   $HOME/.touchbar-island/bin/tbpermission"
echo "   $HOME/.touchbar-island/bin/tbdone"
echo "   $HOME/.touchbar-island/bin/tberror"
echo "   $HOME/.touchbar-island/bin/tbstatus"
echo "   $HOME/.touchbar-island/bin/tbclear"

