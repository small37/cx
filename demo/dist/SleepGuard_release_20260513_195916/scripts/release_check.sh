#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
APP_BIN="$PROJECT_ROOT/build/SleepGuardDemo.app/Contents/MacOS/SleepGuardDemo"
SOCK="$HOME/.touchbar-island/touchbar.sock"
REPORT_DIR="$HOME/.touchbar-island"
LOG_FILE="$REPORT_DIR/release_check_$(date +%Y%m%d_%H%M%S).txt"
BIN_DIR="$HOME/.touchbar-island/bin"

CPU_THRESHOLD="${CPU_THRESHOLD:-1.0}"
RSS_MB_THRESHOLD="${RSS_MB_THRESHOLD:-60.0}"

mkdir -p "$REPORT_DIR"
{
  echo "SleepGuard Release Check"
  echo "date=$(date)"
  echo "cpu_threshold=$CPU_THRESHOLD"
  echo "rss_mb_threshold=$RSS_MB_THRESHOLD"
  echo
} > "$LOG_FILE"

fail() {
  echo "FAIL: $1" | tee -a "$LOG_FILE"
  exit 1
}

pass() {
  echo "PASS: $1" | tee -a "$LOG_FILE"
}

[[ -x "$APP_BIN" ]] || fail "app binary missing: $APP_BIN"
pass "app binary exists"

for cmd in tbmsg tbpermission tbdone tberror tbstatus tbclear; do
  if command -v "$cmd" >/dev/null 2>&1; then
    :
  elif [ -x "$BIN_DIR/$cmd" ]; then
    export PATH="$BIN_DIR:$PATH"
  else
    fail "command not found: $cmd"
  fi
done
pass "tb* commands available in PATH"

pkill -f "$APP_BIN" >/dev/null 2>&1 || true
"$APP_BIN" >/dev/null 2>&1 &
APP_PID=$!
sleep 2
ps -p "$APP_PID" >/dev/null 2>&1 || fail "app failed to start"
pass "app started (pid=$APP_PID)"

[[ -S "$SOCK" ]] || fail "socket not ready: $SOCK"
pass "socket exists"

tbstatus "release_check_ready"
tbmsg "[tag:检查] [text:green:release check message] [flex] [button:关闭:dismiss]"
tbdone "release check done"
tberror "release check error"
tbclear
pass "socket commands sent"

BENCH_OUT="$("$ROOT_DIR/benchmark_resources.sh" | tail -n 1 | awk '{print $1}')"
BENCH_FILE="$(ls -t "$REPORT_DIR"/resource_benchmark_*.txt | head -n 1)"
[[ -f "$BENCH_FILE" ]] || fail "benchmark report missing"
pass "benchmark generated: $BENCH_FILE"

AVG_CPU="$(awk -F'=' '/^avg_cpu_percent=/{print $2}' "$BENCH_FILE" | tail -n 1)"
AVG_RSS_MB="$(awk -F'=' '/^avg_rss_mb=/{print $2}' "$BENCH_FILE" | tail -n 1)"

[[ -n "$AVG_CPU" ]] || fail "avg_cpu_percent missing"
[[ -n "$AVG_RSS_MB" ]] || fail "avg_rss_mb missing"

awk -v v="$AVG_CPU" -v t="$CPU_THRESHOLD" 'BEGIN{exit !(v<=t)}' || fail "avg CPU too high: $AVG_CPU > $CPU_THRESHOLD"
awk -v v="$AVG_RSS_MB" -v t="$RSS_MB_THRESHOLD" 'BEGIN{exit !(v<=t)}' || fail "avg RSS too high: $AVG_RSS_MB MB > $RSS_MB_THRESHOLD MB"
pass "resource thresholds passed (avg_cpu=$AVG_CPU, avg_rss_mb=$AVG_RSS_MB)"

echo >> "$LOG_FILE"
echo "result=PASS" | tee -a "$LOG_FILE"
echo "release_check_log=$LOG_FILE"
