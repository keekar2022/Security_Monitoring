#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Run Trend Micro collectors when schedule is due (daily / weekly / monthly).
#
# Usage:
#   ./scripts/run_scheduled_collect.sh              # local: pass or TRENDMICRO_* env
#   ./scripts/run_scheduled_collect.sh --ec2        # EC2 cron: Secrets Manager + S3
#   FORCE_COLLECT=true ./scripts/run_scheduled_collect.sh
set -euo pipefail

EC2_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ec2) EC2_MODE=true ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/run_scheduled_collect.sh [--ec2]

  (default)  Laptop: pass or TRENDMICRO_*_API_TOKEN env; optional sync_metrics_s3.sh
  --ec2      Production EC2: deploy.env + Secrets Manager + go collector --publish-s3

Environment: FORCE_COLLECT, SECMON_USE_COLLECTOR, METRICS_S3_BUCKET, DATA_DIR, USE_PASS
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --help)" >&2
      exit 1
      ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$EC2_MODE" == true ]]; then
  DEPLOY_ENV="${SECMON_DEPLOY_ENV:-/opt/secmon/deploy.env}"
  if [[ -f "$DEPLOY_ENV" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$DEPLOY_ENV"
    set +a
  fi
  export DATA_DIR="${DATA_DIR:-/opt/secmon/data}"
  export COLLECTION_TRIGGER="${COLLECTION_TRIGGER:-ec2-cron}"
  export USE_PASS="${USE_PASS:-false}"
  export COLLECTOR_NON_FATAL="${COLLECTOR_NON_FATAL:-true}"
  export SECMON_USE_COLLECTOR=true

  "$ROOT/scripts/ec2_fetch_secrets.sh"

  set -a
  # shellcheck source=/dev/null
  source /run/secmon/collect.env
  set +a

  export METRICS_S3_BUCKET="${METRICS_S3_BUCKET:?Set METRICS_S3_BUCKET in $DEPLOY_ENV (see user-data)}"
fi

BIN_DIR="$ROOT/go/bin"
COLLECTOR="$BIN_DIR/collector"
DATA_DIR="${DATA_DIR:-$ROOT/data}"
USE_COLLECTOR="${SECMON_USE_COLLECTOR:-}"
PYTHON="${PYTHON:-python3}"
FORCE="${FORCE_COLLECT:-false}"
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

# Unified collector path (EC2 / when SECMON_USE_COLLECTOR=true) — S3 via --publish-s3 only
if [[ "$USE_COLLECTOR" == "true" && -x "$COLLECTOR" ]]; then
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
  fi
  PUBLISH_FLAG=()
  [[ -n "${METRICS_S3_BUCKET:-}" ]] && PUBLISH_FLAG=(--publish-s3)
  NON_FATAL_FLAG=()
  [[ "${COLLECTOR_NON_FATAL:-}" == "true" ]] && NON_FATAL_FLAG=(--non-fatal)
  START_TS=$(date +%s)
  set +e
  "$COLLECTOR" --run-all --output-dir "$DATA_DIR" --bin-dir "$BIN_DIR" "${PUBLISH_FLAG[@]}" "${NON_FATAL_FLAG[@]}"
  CODE=$?
  set -e
  END_TS=$(date +%s)
  DURATION=$((END_TS - START_TS))
  if [[ "$CODE" -eq 0 ]]; then
    export COLLECTION_TRIGGER="$TRIGGER"
    export COLLECTION_DURATION="$DURATION"
    export COLLECTION_ENV_LIST="${ENVIRONMENTS[*]}"
    export COLLECTION_FAILED_ENV_LIST=""
    export COLLECTION_PARTIAL_ENV_LIST=""
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
  fi
  exit "$CODE"
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

ENDPOINT_VULN_EXTRA=()
[[ "${COLLECTOR_NON_FATAL:-}" == "true" ]] && ENDPOINT_VULN_EXTRA=(--non-fatal)

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

if [[ -n "${METRICS_S3_BUCKET:-}" && "$EC2_MODE" != true ]]; then
  echo "Publishing metrics to S3..."
  METRICS_S3_BUCKET="$METRICS_S3_BUCKET" DATA_DIR="$DATA_DIR" "$ROOT/scripts/sync_metrics_s3.sh"
fi
