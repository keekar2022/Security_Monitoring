#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Sync local metrics JSONL to S3 (shared by push_local_metrics_to_s3.sh and run_scheduled_collect.sh).
# EC2 cron uses go/bin/collector --publish-s3 instead; do not call this after collector on EC2.
#
# Requires: METRICS_S3_BUCKET, DATA_DIR (optional: METRICS_S3_PREFIX, AWS_REGION, SYNC_DRY_RUN=true)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${DATA_DIR:-}" ]]; then
  if [[ -d /opt/secmon/data ]]; then
    DATA_DIR=/opt/secmon/data
  elif [[ -d "$ROOT/data" ]]; then
    DATA_DIR="$ROOT/data"
  else
    DATA_DIR=/opt/secmon/data
  fi
fi
BUCKET="${METRICS_S3_BUCKET:?Set METRICS_S3_BUCKET}"
PREFIX="${METRICS_S3_PREFIX:-data}"

if [[ ! -d "$DATA_DIR" ]]; then
  echo "ERROR: DATA_DIR not found: $DATA_DIR" >&2
  exit 1
fi

DEST="s3://${BUCKET}/${PREFIX}/"
AWS_ARGS=()
[[ -n "${AWS_REGION:-}" ]] && AWS_ARGS=(--region "$AWS_REGION")
[[ "${SYNC_DRY_RUN:-}" == "true" ]] && AWS_ARGS+=(--dryrun)

echo "Uploading $DATA_DIR -> $DEST"
aws s3 sync "$DATA_DIR/" "$DEST" "${AWS_ARGS[@]}"
echo "S3 sync complete"
