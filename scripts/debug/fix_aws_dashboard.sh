#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# One-shot fix for AWS 502 + missing Container/Endpoint data + non-executable scripts.
#
# Usage:
#   ./scripts/debug/fix_aws_dashboard.sh
#   ./scripts/debug/fix_aws_dashboard.sh 2.0.0

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

VERSION="${1:-$(grep '^VERSION=' "$ROOT/VERSION" | cut -d= -f2)}"
export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
deploy_export_aws_region

aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERROR: AWS credentials not active (pass show $AWS_PASS_ENTRY)" >&2
  exit 1
}

BUCKET="$(deploy_s3_bucket)" || { echo "ERROR: S3 bucket unknown" >&2; exit 1; }

deploy_log "=== Fix AWS dashboard (release $VERSION) ==="
deploy_log "1/4 Upload local metrics (all JSONL + legacy) to S3"
DATA_DIR="$ROOT/data" METRICS_S3_BUCKET="$BUCKET" "$ROOT/scripts/push_local_metrics_to_s3.sh"

deploy_log "2/4 Publish app release with executable bits"
"$ROOT/scripts/package_app_release.sh" "$VERSION" "$BUCKET"

deploy_log "3/4 Repair EC2 (sync app+data, chmod, venv, secrets, Streamlit)"
"$ROOT/scripts/debug/repair_ec2_streamlit.sh" "$VERSION"

deploy_log "4/4 Diagnostics"
"$ROOT/scripts/debug/diagnose_aws_deploy.sh"

ALB_DNS="$(deploy_tf_output alb_dns_name 2>/dev/null || true)"
echo ""
deploy_log "Done. Open: http://${ALB_DNS:-<alb-dns>}/"
deploy_log "Use Reload data on each tab if charts are stale."
