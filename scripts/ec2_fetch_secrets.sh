#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Refresh /run/secmon/*.env from Secrets Manager (no secrets on disk in repo).
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-us-east-1}}"
ENV_DIR="${SECMON_ENV_DIR:-/run/secmon}"
DEPLOY_ENV="${SECMON_DEPLOY_ENV:-/opt/secmon/deploy.env}"
SECRET_APP="${SECMON_SECRET_APP:-ams-secmon/secmon/app}"
SECRET_TM="${SECMON_SECRET_TRENDMICRO:-ams-secmon/secmon/trendmicro}"

mkdir -p "$ENV_DIR"
if [[ -w "$ENV_DIR" ]]; then
  chmod 700 "$ENV_DIR" 2>/dev/null || true
fi

# Bootstrap / Terraform bucket name (written by user-data)
if [[ -f "$DEPLOY_ENV" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$DEPLOY_ENV"
  set +a
fi

_fetch() {
  local name="$1" json_out="$2" env_out="$3"
  aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$name" \
    --query SecretString \
    --output text > "$json_out"
  chmod 600 "$json_out" 2>/dev/null || true
  jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' "$json_out" > "$env_out"
  chmod 600 "$env_out" 2>/dev/null || true
}

_fetch "$SECRET_APP" "$ENV_DIR/app.json" "$ENV_DIR/app.env"
_fetch "$SECRET_TM" "$ENV_DIR/trendmicro.json" "$ENV_DIR/collect.env"

_append_if_missing() {
  local file="$1" key="$2" val="$3"
  [[ -n "$val" ]] || return 0
  if ! grep -q "^${key}=" "$file" 2>/dev/null; then
    echo "${key}=${val}" >> "$file"
  fi
}

_merge_deploy_env() {
  local file="$1"
  _append_if_missing "$file" METRICS_S3_BUCKET "${METRICS_S3_BUCKET:-}"
  _append_if_missing "$file" DATA_DIR "${DATA_DIR:-/opt/secmon/data}"
  _append_if_missing "$file" AWS_DEFAULT_REGION "${AWS_DEFAULT_REGION:-$REGION}"
  _append_if_missing "$file" SECMON_COLLECTION_MODE "${SECMON_COLLECTION_MODE:-ec2}"
  _append_if_missing "$file" USE_PASS "${USE_PASS:-false}"
  _append_if_missing "$file" COLLECTOR_NON_FATAL "${COLLECTOR_NON_FATAL:-true}"
}

_merge_deploy_env "$ENV_DIR/app.env"
_merge_deploy_env "$ENV_DIR/collect.env"
_append_if_missing "$ENV_DIR/app.env" SECMON_COLLECTION_MODE ec2
_append_if_missing "$ENV_DIR/app.env" DATA_DIR "${DATA_DIR:-/opt/secmon/data}"

echo "Secrets refreshed under $ENV_DIR"
