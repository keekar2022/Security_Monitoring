#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Upload dashboard metrics from your laptop to S3 (source of truth for EC2).
# New instances sync s3://<bucket>/data/ on bootstrap; use instance refresh after upload.
#
# Usage:
#   ./scripts/push_local_metrics_to_s3.sh
#   METRICS_S3_BUCKET=my-bucket DATA_DIR=./data ./scripts/push_local_metrics_to_s3.sh
#   ./scripts/push_local_metrics_to_s3.sh --dry-run

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      echo "  Uploads repo data/ (or DATA_DIR) to s3://<bucket>/data/"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

deploy_require_tools
export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
deploy_export_aws_region

DATA_DIR="${DATA_DIR:-$ROOT/data}"
if [[ ! -d "$DATA_DIR" ]]; then
  echo "ERROR: DATA_DIR not found: $DATA_DIR" >&2
  exit 1
fi

BUCKET="$(deploy_s3_bucket)"
[[ -n "$BUCKET" ]] || {
  echo "ERROR: Set METRICS_S3_BUCKET or run Terraform apply first." >&2
  exit 1
}

deploy_log "Local metrics: $DATA_DIR"
deploy_log "Destination:   s3://${BUCKET}/${METRICS_S3_PREFIX:-data}/"

export METRICS_S3_BUCKET="$BUCKET"
export DATA_DIR
[[ "$DRY_RUN" == true ]] && export SYNC_DRY_RUN=true
"$ROOT/scripts/sync_metrics_s3.sh"

if [[ "$DRY_RUN" != true ]]; then
  deploy_log "Upload complete. Sync to running EC2 (preferred):"
  deploy_log "  ./scripts/debug/sync_ec2_metrics_from_s3.sh"
  deploy_log "Or full repair: ./scripts/debug/fix_aws_dashboard.sh"
fi
