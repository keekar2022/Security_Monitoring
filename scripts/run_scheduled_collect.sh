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

ENVIRONMENTS=()
while IFS= read -r _env_line; do
  [[ -n "$_env_line" ]] && ENVIRONMENTS+=("$_env_line")
done < <(
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

SUCCEEDED_ENVS=()
FAILED_ENVS=()
PARTIAL_ENVS=()

# In GitHub Actions, endpoint ASRM may lack permissions; do not fail the whole workflow.
ENDPOINT_VULN_EXTRA=()
if [[ "${COLLECTOR_NON_FATAL:-}" == "true" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  ENDPOINT_VULN_EXTRA=(--non-fatal)
fi

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
    "$BIN_DIR/get_endpoint_vulnerabilities" --environment "$env" --output-dir "$DATA_DIR" --quiet \
      "${ENDPOINT_VULN_EXTRA[@]}"
  ) &
  PID3=$!
  CONTAINER_OK=0
  STATS_OK=0
  VULN_OK=0
  wait "$PID1" && CONTAINER_OK=1 || true
  wait "$PID2" && STATS_OK=1 || true
  wait "$PID3" && VULN_OK=1 || true

  if [[ "$CONTAINER_OK" -eq 1 ]]; then
    if [[ "$STATS_OK" -eq 1 && "$VULN_OK" -eq 1 ]]; then
      SUCCEEDED_ENVS+=("$env")
      echo "All collectors succeeded for $env"
    else
      PARTIAL_ENVS+=("$env")
      echo "WARNING: Partial collection for $env (container=ok stats=$STATS_OK endpoint_vuln=$VULN_OK)"
    fi
  else
    echo "ERROR: Container collector failed for $env (required)"
    FAILED_ENVS+=("$env")
  fi
done

if [[ ${#SUCCEEDED_ENVS[@]} -eq 0 && ${#PARTIAL_ENVS[@]} -eq 0 ]]; then
  die "All environments failed: ${FAILED_ENVS[*]:-none}"
fi
if [[ ${#PARTIAL_ENVS[@]} -gt 0 ]]; then
  echo "Partial collectors: ${PARTIAL_ENVS[*]} (container metrics collected; check ASRM API permissions for endpoints)"
fi
if [[ ${#FAILED_ENVS[@]} -gt 0 ]]; then
  echo "Failed environments: ${FAILED_ENVS[*]}"
fi

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

export COLLECTION_TRIGGER="$TRIGGER"
export COLLECTION_DURATION="$DURATION"
export COLLECTION_ENV_LIST="${SUCCEEDED_ENVS[*]} ${PARTIAL_ENVS[*]}"
export COLLECTION_FAILED_ENV_LIST="${FAILED_ENVS[*]}"
export COLLECTION_PARTIAL_ENV_LIST="${PARTIAL_ENVS[*]}"
"$PYTHON" - <<'PY'
import os
from monitoring_dashboard.collection_schedule import write_meta_after_success

envs = [e for e in os.environ.get("COLLECTION_ENV_LIST", "").split() if e]
failed = [e for e in os.environ.get("COLLECTION_FAILED_ENV_LIST", "").split() if e]
partial = [e for e in os.environ.get("COLLECTION_PARTIAL_ENV_LIST", "").split() if e]
write_meta_after_success(
    environments=envs,
    duration_seconds=float(os.environ.get("COLLECTION_DURATION", "0")),
    trigger=os.environ.get("COLLECTION_TRIGGER", "local"),
    failed_environments=failed or None,
    partial_environments=partial or None,
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
