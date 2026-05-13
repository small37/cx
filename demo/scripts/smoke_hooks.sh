#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BIN="$(cd "$ROOT_DIR/.." && pwd)/build/SleepGuardDemo.app/Contents/MacOS/SleepGuardDemo"
SOCK="$HOME/.touchbar-island/touchbar.sock"
BIN_DIR="$HOME/.touchbar-island/bin"
REPORT="$HOME/.touchbar-island/smoke_hooks_$(date +%Y%m%d_%H%M%S).txt"

mkdir -p "$HOME/.touchbar-island"
export PATH="$BIN_DIR:$PATH"

for cmd in tbmsg tbpermission tbdone tberror tbstatus tbclear; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing command: $cmd" | tee -a "$REPORT"
    exit 1
  }
done

pkill -f "$APP_BIN" >/dev/null 2>&1 || true
"$APP_BIN" >/dev/null 2>&1 &
APP_PID=$!
sleep 2

{
  echo "Smoke Hooks Report"
  echo "date=$(date)"
  echo "pid=$APP_PID"
} > "$REPORT"

if [ ! -S "$SOCK" ]; then
  echo "FAIL socket missing: $SOCK" | tee -a "$REPORT"
  exit 1
fi

tbstatus "smoke_ready"
tbmsg "[tag:通知] [text:white:smoke msg] [flex] [button:关闭:dismiss]"
sleep 1
tbpermission "Claude 需要你确认权限"
sleep 1
tbdone "任务完成"
sleep 1
tberror "命令失败"
sleep 1
tbclear
sleep 1

echo "PASS commands sent" | tee -a "$REPORT"

if [ -f "$HOME/.touchbar-island/action.log" ]; then
  echo "action_log_tail:" >> "$REPORT"
  tail -n 5 "$HOME/.touchbar-island/action.log" >> "$REPORT" || true
fi

echo "Run resource benchmark..." | tee -a "$REPORT"
"$ROOT_DIR/benchmark_resources.sh" >/dev/null
LATEST_BENCH="$(ls -t "$HOME/.touchbar-island"/resource_benchmark_*.txt | head -n 1)"
echo "benchmark_report=$LATEST_BENCH" | tee -a "$REPORT"
tail -n 8 "$LATEST_BENCH" >> "$REPORT"

echo "PASS smoke done" | tee -a "$REPORT"
echo "report=$REPORT"

