#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Roll back the EC2/ALB compute stack (like a partial CloudFormation rollback).
# PRESERVES: S3 bucket + all objects (releases/, data/), Secrets Manager secrets.
#
# Does NOT run full `terraform destroy` (that would try to delete S3; bucket has
# lifecycle prevent_destroy — apply would block S3 deletion).
#
# Usage (from repo root):
#   ./terraform/scripts/rollback-compute-preserve-s3.sh
#   ./terraform/scripts/rollback-compute-preserve-s3.sh --yes
#
# Re-deploy after rollback:
#   ./terraform/run-with-aws-pass.sh apply
#   ./scripts/aws_deploy.sh --full --skip-terraform

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${TERRAFORM_DIR:-$(cd "$SCRIPT_DIR/../envs/aws1590" && pwd)}"
ENTRY="${AWS_PASS_ENTRY:-AWS/AMS_1590-STG}"
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) AUTO_YES=true ;;
    -h|--help)
      sed -n '1,20p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

load_aws() {
  command -v pass >/dev/null 2>&1 || return 0
  while IFS= read -r line; do
    if [[ $line =~ ^(aws_[a-z_]+)=(.*)$ ]]; then
      case "${BASH_REMATCH[1]}" in
        aws_access_key_id) export AWS_ACCESS_KEY_ID="${BASH_REMATCH[2]}" ;;
        aws_secret_access_key) export AWS_SECRET_ACCESS_KEY="${BASH_REMATCH[2]}" ;;
        aws_session_token) export AWS_SESSION_TOKEN="${BASH_REMATCH[2]}" ;;
      esac
    fi
  done < <(pass show "$ENTRY" 2>/dev/null || true)
}

load_aws
cd "$TF_DIR"

# Order: attachment → ASG → listeners → ALB → TG → launch template
TARGETS=(
  "aws_autoscaling_attachment.secmon"
  "aws_autoscaling_group.secmon"
  "aws_launch_template.secmon"
  "aws_lb_listener.http_forward[0]"
  "aws_lb_listener.http_redirect[0]"
  "aws_lb_listener.https[0]"
  "aws_lb.main"
  "aws_lb_target_group.streamlit"
)

echo "=== Rollback compute (preserve S3 + Secrets Manager) ==="
echo "Terraform dir: $TF_DIR"
echo "Targets:"
printf '  - %s\n' "${TARGETS[@]}"
echo ""
echo "KEPT: aws_s3_bucket.secmon (prevent_destroy), secrets, VPC (for faster re-apply)."
echo "S3 data: s3://<bucket>/releases/ and s3://<bucket>/data/ are NOT deleted."
echo ""

if [[ "$AUTO_YES" != true ]]; then
  read -r -p "Type 'rollback' to continue: " confirm
  [[ "$confirm" == "rollback" ]] || { echo "Aborted."; exit 1; }
fi

ARGS=()
for t in "${TARGETS[@]}"; do
  ARGS+=("-target=$t")
done

terraform destroy "${ARGS[@]}" -auto-approve

echo ""
echo "Compute stack removed. Re-create with:"
echo "  ./terraform/run-with-aws-pass.sh apply"
echo "  ./scripts/debug/fix_aws_dashboard.sh"
