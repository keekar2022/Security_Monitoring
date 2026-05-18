#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Initialize and start Keekar's Security Monitoring Dashboard (app.py, v1.0.11+).
# Legacy AEM/Splunk tab: docs/AEM_GOVAU_LEGACY_DASHBOARD.md
# Stops any existing Streamlit or static HTTP server for this project first.
#
# Usage:
#   ./scripts/start_dashboard.sh          # stop conflicts, init, start
#   ./scripts/start_dashboard.sh stop     # stop only (no start)
#   STREAMLIT_PORT=8502 ./scripts/start_dashboard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="${VENV_DIR:-$ROOT/.venv}"
APP_PY="$ROOT/app.py"
DATA_DIR="${DATA_DIR:-$ROOT/data}"
STREAMLIT_PORT="${STREAMLIT_PORT:-8501}"
STATIC_PORT="${STATIC_PORT:-8080}"
RUN_DIR="$ROOT/.run"
PIDFILE="$RUN_DIR/dashboard.pid"

log() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

# --- Stop helpers -----------------------------------------------------------

stop_pids() {
  local sig=$1
  shift
  local pid
  for pid in "$@"; do
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill "-$sig" "$pid" 2>/dev/null || true
    fi
  done
}

pids_on_port() {
  local port=$1
  lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | tr '\n' ' ' || true
}

stop_listeners_on_port() {
  local port=$1
  local label=$2
  local pids
  pids=$(pids_on_port "$port")
  if [[ -z "${pids// }" ]]; then
    return 0
  fi
  log "Stopping $label on port $port (PID(s): $pids)"
  # shellcheck disable=SC2086
  stop_pids TERM $pids
  sleep 1
  pids=$(pids_on_port "$port")
  if [[ -n "${pids// }" ]]; then
    warn "Force-stopping remaining process(es) on port $port"
    # shellcheck disable=SC2086
    stop_pids KILL $pids
  fi
}

stop_pidfile() {
  if [[ ! -f "$PIDFILE" ]]; then
    return 0
  fi
  local pid pids=""
  while read -r pid; do
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      pids="$pids $pid"
    fi
  done < "$PIDFILE"
  if [[ -n "${pids// }" ]]; then
    log "Stopping previous dashboard PID(s) from $PIDFILE:$pids"
    # shellcheck disable=SC2086
    stop_pids TERM $pids
    sleep 1
    # shellcheck disable=SC2086
    stop_pids KILL $pids
  fi
  rm -f "$PIDFILE"
}

stop_project_background_servers() {
  log "Checking for existing dashboard / static servers for this project..."

  stop_pidfile
  stop_listeners_on_port "$STREAMLIT_PORT" "Streamlit"
  stop_listeners_on_port "$STATIC_PORT" "static HTTP (jsonl_viewer / data)"

  if [[ -z "$(pids_on_port "$STREAMLIT_PORT")" ]] && [[ -z "$(pids_on_port "$STATIC_PORT")" ]]; then
    log "Ports $STREAMLIT_PORT and $STATIC_PORT are free."
  fi
}

# --- Init -------------------------------------------------------------------

init_environment() {
  log "Initializing environment in: $ROOT"

  if [[ ! -d "$VENV_DIR" ]]; then
    log "Creating virtualenv: $VENV_DIR"
    python3 -m venv "$VENV_DIR"
  fi

  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"

  log "Installing Python dependencies..."
  export PIP_NO_CACHE_DIR=1
  python -m pip install -q --upgrade pip
  python -m pip install -q -r "$ROOT/requirements.txt"
  unset PIP_NO_CACHE_DIR

  if [[ ! -f "$ROOT/.env" ]] && [[ -f "$ROOT/.env.example" ]]; then
    log "Creating .env from .env.example"
    cp "$ROOT/.env.example" "$ROOT/.env"
  fi

  mkdir -p "$ROOT/config" "$DATA_DIR" "$RUN_DIR"

  if [[ ! -f "$APP_PY" ]]; then
    echo "ERROR: Missing $APP_PY" >&2
    exit 1
  fi
}

# --- Start ------------------------------------------------------------------

start_streamlit() {
  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"

  if [[ "$DATA_DIR" != /* ]]; then
    DATA_DIR="$ROOT/$DATA_DIR"
  fi
  export DATA_DIR

  if [[ -z "${OKTA_REDIRECT_URI:-}" ]]; then
    export OKTA_REDIRECT_URI="http://localhost:${STREAMLIT_PORT}/"
  fi
  if [[ -z "${STREAMLIT_APP_URL:-}" ]]; then
    export STREAMLIT_APP_URL="http://localhost:${STREAMLIT_PORT}/"
  fi

  export STREAMLIT_CONFIG_DIR="$ROOT/.streamlit"
  export STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
  export STREAMLIT_SERVER_HEADLESS=true
  export STREAMLIT_SERVER_PORT="$STREAMLIT_PORT"
  export STREAMLIT_SERVER_ADDRESS=localhost

  log ""
  log "Starting Streamlit dashboard..."
  log "  URL:  http://localhost:${STREAMLIT_PORT}/"
  log "  App:  $APP_PY"
  log "  Data: $DATA_DIR"
  log ""
  log "Press Ctrl+C to stop."
  log ""

  cd "$ROOT"

  # Foreground run (no background &) so logs stay attached and first-run prompts stay disabled.
  cleanup_on_exit() {
    rm -f "$PIDFILE"
  }
  trap cleanup_on_exit INT TERM EXIT

  streamlit run app.py \
    --server.port "$STREAMLIT_PORT" \
    --server.address localhost \
    --server.headless true \
    --browser.gatherUsageStats false \
    --server.showEmailPrompt false &
  local st_pid=$!
  echo "$st_pid" >"$PIDFILE"
  sleep 2
  if ! kill -0 "$st_pid" 2>/dev/null; then
    echo "ERROR: Streamlit exited immediately. Check messages above." >&2
    rm -f "$PIDFILE"
    exit 1
  fi
  log "Streamlit running (PID $st_pid). Open http://localhost:${STREAMLIT_PORT}/"
  wait "$st_pid" || true
  rm -f "$PIDFILE"
}

# --- Main -------------------------------------------------------------------

main() {
  local action="${1:-start}"

  case "$action" in
    stop)
      stop_project_background_servers
      log "Stopped."
      ;;
    start)
      stop_project_background_servers
      init_environment
      start_streamlit
      ;;
    restart)
      stop_project_background_servers
      init_environment
      start_streamlit
      ;;
    *)
      echo "Usage: $0 [start|stop|restart]" >&2
      exit 1
      ;;
  esac
}

main "$@"
