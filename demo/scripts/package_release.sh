#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
TOP_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
DIST_ROOT="$PROJECT_ROOT/dist"
STAMP="$(date +%Y%m%d_%H%M%S)"
PKG_DIR="$DIST_ROOT/SleepGuard_release_$STAMP"
ARCHIVE="$DIST_ROOT/SleepGuard_release_$STAMP.tar.gz"

"$PROJECT_ROOT/build.sh"
mkdir -p "$PKG_DIR"

cp -R "$PROJECT_ROOT/build/SleepGuardDemo.app" "$PKG_DIR/"
cp "$PROJECT_ROOT/build/tbsend_swift" "$PKG_DIR/"

mkdir -p "$PKG_DIR/scripts" "$PKG_DIR/docs"
cp "$ROOT_DIR"/tb* "$PKG_DIR/scripts/"
cp "$ROOT_DIR"/install_commands.sh "$PKG_DIR/scripts/"
cp "$ROOT_DIR"/install_claude_hooks.sh "$PKG_DIR/scripts/"
cp "$ROOT_DIR"/merge_claude_hooks.sh "$PKG_DIR/scripts/"
cp "$ROOT_DIR"/benchmark_resources.sh "$PKG_DIR/scripts/"
cp "$ROOT_DIR"/release_check.sh "$PKG_DIR/scripts/"
cp "$ROOT_DIR"/smoke_hooks.sh "$PKG_DIR/scripts/"

cp "$TOP_ROOT/docs/claude_hooks.touchbar.example.json" "$PKG_DIR/docs/"
cp "$TOP_ROOT/README.md" "$PKG_DIR/docs/README.md"

cat > "$PKG_DIR/quickstart.txt" <<'EOF'
1) Launch app:
   open ./SleepGuardDemo.app

2) Install command scripts:
   cd ./scripts
   ./install_commands.sh

3) Install hooks template:
   ./install_claude_hooks.sh

4) Merge template into your Claude hooks config:
   ./merge_claude_hooks.sh /path/to/your/hooks.json

5) Smoke test:
   tbmsg "TouchBar online"
   tbpermission "Need confirm"

6) Resource check:
   ./release_check.sh

7) End-to-end smoke:
   ./smoke_hooks.sh
EOF

chmod +x "$PKG_DIR/scripts/"*.sh "$PKG_DIR/scripts/"tb*
tar -czf "$ARCHIVE" -C "$DIST_ROOT" "$(basename "$PKG_DIR")"

echo "Package directory:"
echo "  $PKG_DIR"
echo "Package archive:"
echo "  $ARCHIVE"
