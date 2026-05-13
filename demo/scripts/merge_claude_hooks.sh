#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
PATCH_FILE="$PROJECT_ROOT/docs/claude_hooks.touchbar.example.json"

TARGET_FILE="${1:-$HOME/.claude/hooks.json}"
BACKUP_FILE="${TARGET_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
TMP_FILE="$(mktemp)"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for merge_claude_hooks.sh"
  echo "Install jq, then re-run."
  exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
  echo "Patch file not found: $PATCH_FILE"
  exit 1
fi

mkdir -p "$(dirname "$TARGET_FILE")"

if [ ! -f "$TARGET_FILE" ]; then
  echo '{}' > "$TARGET_FILE"
fi

cp "$TARGET_FILE" "$BACKUP_FILE"

jq --slurpfile patch "$PATCH_FILE" '
  def merge_event($base; $extra):
    (($base // []) + ($extra // []))
    | unique_by((.matcher // "") + "|" + ((.hooks // [] | map(.type // "" + ":" + (.command // "")) | join(","))));

  . as $root
  | ($root.hooks // {}) as $baseHooks
  | ($patch[0].hooks // {}) as $patchHooks
  | ($baseHooks + $patchHooks | keys_unsorted) as $allKeys
  | .hooks = (
      reduce $allKeys[] as $k ({}; .[$k] = merge_event($baseHooks[$k]; $patchHooks[$k]))
    )
' "$TARGET_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$TARGET_FILE"

echo "Merged hooks into:"
echo "  $TARGET_FILE"
echo "Backup:"
echo "  $BACKUP_FILE"
