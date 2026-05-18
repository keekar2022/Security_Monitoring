#!/usr/bin/env bash
# Run three collectors in parallel, sleep 60s, then serve data/ on :8080 for 15 minutes and stop.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BIN_DIR="$ROOT/go/bin"
DATA_DIR="$ROOT/data"

get_container="$BIN_DIR/get_container_vulnerabilities"
get_endpoint_stats="$BIN_DIR/get_endpoint_stats"
get_endpoint_vuln="$BIN_DIR/get_endpoint_vulnerabilities"

for f in "$get_container" "$get_endpoint_stats" "$get_endpoint_vuln"; do
  if [[ ! -x "$f" ]]; then
    echo "Missing or not executable: $f" >&2
    exit 1
  fi
done

SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "Stopping web server (pid ${SERVER_PID})..."
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

echo "Starting collectors in parallel from: $BIN_DIR"
"$get_container" &
PID1=$!
"$get_endpoint_stats" &
PID2=$!
"$get_endpoint_vuln" &
PID3=$!

echo "Waiting 60 seconds (collectors continue in background)..."
sleep 60

echo "Starting HTTP server on port 8080 (data dir: $DATA_DIR) for 15 minutes..."
cd "$DATA_DIR" || exit 1
python3 -m http.server 8080 &
SERVER_PID=$!

sleep 900

echo "15 minutes elapsed; exiting (web server will be stopped)."
exit 0
