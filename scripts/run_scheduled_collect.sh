#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Run Trend Micro collectors when schedule is due (daily / weekly / monthly).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BIN_DIR="$ROOT/go/bin"
DATA_DIR="${DATA_DIR:-$ROOT/data}"
PYTHON="${PYTHON:-python3}"
FORCE="${FORCE_COLLECT:-false}"
AUTO_PUSH="${AUTO_PUSH:-false}"
PUSH_AFTER_COLLECT="${PUSH_AFTER_COLLECT:-false}"
TRIGGER="${COLLECTION_TRIGGER:-local}"
USE_PASS="${USE_PASS:-}"

export DATA_DIR

die() { echo "ERROR: $*" >&2; exit 1; }

for f in \
  "$BIN_DIR/get_container_vulnerabilities" \
  "$BIN_DIR/get_endpoint_stats" \
  "$BIN_DIR/get_endpoint_vulnerabilities"; do
  if [[ ! -x "$f" ]]; then
    die "Missing collector binary: $f (run: make -C go tools)"
  fi
done

mapfile -t ENVIRONMENTS < <(
  "$PYTHON" - <<'PY'
from monitoring_dashboard.collection_schedule import list_credentialed_environments
for e in list_credentialed_environments():
    print(e)
PY
)

if [[ ${#ENVIRONMENTS[@]} -eq 0 ]]; then
  die "No environments in config/deployment_config.json"
fi

if [[ "$FORCE" != "true" ]]; then
  set +e
  CHECK_OUT="$("$PYTHON" -m monitoring_dashboard.collection_schedule --check 2>&1)"
  CHECK_CODE=$?
  set -e
  echo "$CHECK_OUT"
  if [[ "$CHECK_CODE" -eq 2 ]]; then
    echo "Collection skipped (not due)."
    exit 0
  fi
  if [[ "$CHECK_CODE" -ne 0 ]]; then
    die "Schedule check failed (exit $CHECK_CODE)"
  fi
else
  echo "FORCE_COLLECT=true — running regardless of schedule"
fi

if [[ -z "$USE_PASS" ]]; then
  if command -v pass >/dev/null 2>&1 && pass ls >/dev/null 2>&1; then
    export USE_PASS=true
  else
    export USE_PASS=false
  fi
fi
export USE_PASS

START_TS=$(date +%s)
echo "Starting collection for environments: ${ENVIRONMENTS[*]}"
echo "USE_PASS=$USE_PASS DATA_DIR=$DATA_DIR trigger=$TRIGGER"

for env in "${ENVIRONMENTS[@]}"; do
  echo "=== Environment: $env ==="
  (
    "$BIN_DIR/get_container_vulnerabilities" --environment "$env" --output-dir "$DATA_DIR" --quiet
  ) &
  PID1=$!
  (
    "$BIN_DIR/get_endpoint_stats" --environment "$env" --output-dir "$DATA_DIR" --quiet
  ) &
  PID2=$!
  (
    "$BIN_DIR/get_endpoint_vulnerabilities" --environment "$env" --output-dir "$DATA_DIR" --quiet
  ) &
  PID3=$!
  FAIL=0
  wait "$PID1" || FAIL=1
  wait "$PID2" || FAIL=1
  wait "$PID3" || FAIL=1
  if [[ "$FAIL" -ne 0 ]]; then
    die "One or more collectors failed for environment $env"
  fi
done

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

export COLLECTION_TRIGGER="$TRIGGER"
export COLLECTION_DURATION="$DURATION"
export COLLECTION_ENV_LIST="${ENVIRONMENTS[*]}"
"$PYTHON" - <<'PY'
import os
from monitoring_dashboard.collection_schedule import write_meta_after_success

envs = [e for e in os.environ.get("COLLECTION_ENV_LIST", "").split() if e]
write_meta_after_success(
    environments=envs,
    duration_seconds=float(os.environ.get("COLLECTION_DURATION", "0")),
    trigger=os.environ.get("COLLECTION_TRIGGER", "local"),
)
print("Wrote collection_meta.json")
PY

echo "Collection finished in ${DURATION}s"

if [[ "$AUTO_PUSH" == "true" || "$PUSH_AFTER_COLLECT" == "true" ]]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "AUTO_PUSH requested but not a git repository"
  fi
  BRANCH="$(git branch --show-current)"
  git add data/*.jsonl data/collection_meta.json 2>/dev/null || true
  if git diff --cached --quiet; then
    echo "No data changes to commit."
  else
    git commit -m "chore: update security metrics data [skip ci]"
    git push origin "$BRANCH"
    echo "Pushed data updates to origin/$BRANCH"
  fi
fi
