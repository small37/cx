#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
APP_BIN="$PROJECT_ROOT/build/SleepGuardDemo.app/Contents/MacOS/SleepGuardDemo"
REPORT_DIR="$HOME/.touchbar-island"
REPORT_FILE="$REPORT_DIR/resource_benchmark_$(date +%Y%m%d_%H%M%S).txt"
SAMPLES=10
INTERVAL=1

mkdir -p "$REPORT_DIR"

if [ ! -x "$APP_BIN" ]; then
  echo "App binary not found: $APP_BIN"
  echo "Please run build first."
  exit 1
fi

# Stop old process to keep results clean.
pkill -f "$APP_BIN" >/dev/null 2>&1 || true

"$APP_BIN" >/dev/null 2>&1 &
APP_PID=$!
sleep 2

if ! ps -p "$APP_PID" >/dev/null 2>&1; then
  echo "Failed to start app for benchmark."
  exit 1
fi

echo "SleepGuard Resource Benchmark" > "$REPORT_FILE"
echo "Date: $(date)" >> "$REPORT_FILE"
echo "PID: $APP_PID" >> "$REPORT_FILE"
echo "Samples: $SAMPLES, interval: ${INTERVAL}s" >> "$REPORT_FILE"
echo >> "$REPORT_FILE"
echo "time,cpu,rss_kb,vsz_kb" >> "$REPORT_FILE"

for _ in $(seq 1 "$SAMPLES"); do
  line="$(ps -p "$APP_PID" -o %cpu=,rss=,vsz= | awk '{$1=$1; print}')"
  cpu="$(echo "$line" | awk '{print $1}')"
  rss="$(echo "$line" | awk '{print $2}')"
  vsz="$(echo "$line" | awk '{print $3}')"
  echo "$(date +%H:%M:%S),$cpu,$rss,$vsz" >> "$REPORT_FILE"
  sleep "$INTERVAL"
done

AVG_CPU="$(awk -F',' '$1 ~ /^[0-9][0-9]:/ {sum+=$2; n++} END {if(n>0) printf "%.3f", sum/n; else print "0"}' "$REPORT_FILE")"
MAX_CPU="$(awk -F',' '$1 ~ /^[0-9][0-9]:/ {if(n==0||$2>max) max=$2; n++} END {if(n>0) printf "%.3f", max; else print "0"}' "$REPORT_FILE")"
AVG_RSS_KB="$(awk -F',' '$1 ~ /^[0-9][0-9]:/ {sum+=$3; n++} END {if(n>0) printf "%.0f", sum/n; else print "0"}' "$REPORT_FILE")"
MAX_RSS_KB="$(awk -F',' '$1 ~ /^[0-9][0-9]:/ {if(n==0||$3>max) max=$3; n++} END {if(n>0) printf "%.0f", max; else print "0"}' "$REPORT_FILE")"
AVG_RSS_MB="$(awk -v kb="$AVG_RSS_KB" 'BEGIN {printf "%.2f", kb/1024}')"
MAX_RSS_MB="$(awk -v kb="$MAX_RSS_KB" 'BEGIN {printf "%.2f", kb/1024}')"

{
  echo
  echo "Summary:"
  echo "avg_cpu_percent=$AVG_CPU"
  echo "max_cpu_percent=$MAX_CPU"
  echo "avg_rss_kb=$AVG_RSS_KB"
  echo "max_rss_kb=$MAX_RSS_KB"
  echo "avg_rss_mb=$AVG_RSS_MB"
  echo "max_rss_mb=$MAX_RSS_MB"
} >> "$REPORT_FILE"

echo "Benchmark report generated:"
echo "  $REPORT_FILE"
