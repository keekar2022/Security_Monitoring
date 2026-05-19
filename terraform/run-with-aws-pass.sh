#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Load AWS credentials from Pass and run Terraform in envs/aws1590 (AMS_1590-STG).
#
# Usage:
#   ./terraform/run-with-aws-pass.sh init|plan|apply [args...]
#   ./terraform/run-with-aws-pass.sh import-key [region]
#
# Optional:
#   AWS_PASS_ENTRY   (default: AWS/AMS_1590-STG)
#   TERRAFORM_DIR    (default: terraform/envs/aws1590)
#   EC2_KEY_NAME     (default: secmon-aws1590)
#   AWS_PASS_SSH_ENTRY

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-$SCRIPT_DIR/envs/aws1590}"
ENTRY="${AWS_PASS_ENTRY:-AWS/AMS_1590-STG}"

load_aws_credentials() {
  command -v pass >/dev/null 2>&1 || {
    echo "pass not found; export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY manually." >&2
    return 0
  }
  while IFS= read -r line; do
    if [[ $line =~ ^(aws_[a-z_]+)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      case "$key" in
        aws_access_key_id) export AWS_ACCESS_KEY_ID="$val" ;;
        aws_secret_access_key) export AWS_SECRET_ACCESS_KEY="$val" ;;
        aws_session_token) export AWS_SESSION_TOKEN="$val" ;;
      esac
    fi
  done < <(pass show "$ENTRY")
}

verify_aws_credentials() {
  command -v aws >/dev/null 2>&1 || return 0
  aws sts get-caller-identity >/dev/null || {
    echo "AWS credentials invalid; refresh Pass entry: $ENTRY" >&2
    exit 1
  }
}

import_ec2_key() {
  local region="${1:-us-east-1}"
  local ssh_entry="${AWS_PASS_SSH_ENTRY:-AWS/SECmon-AWS1590-SSH}"
  local key_name="${EC2_KEY_NAME:-secmon-aws1590}"
  load_aws_credentials
  verify_aws_credentials
  local tmpkey
  tmpkey=$(mktemp)
  trap 'rm -f "$tmpkey"' EXIT
  pass show "$ssh_entry" >"$tmpkey"
  local pubkey
  pubkey=$(ssh-keygen -y -f "$tmpkey")
  aws ec2 import-key-pair \
    --key-name "$key_name" \
    --public-key-material "$(echo -n "$pubkey" | base64)" \
    --region "$region"
  echo "Imported key pair: $key_name"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  import-key)
    import_ec2_key "${1:-us-east-1}"
    ;;
  "")
    echo "Usage: $0 init|plan|apply|import-key ..." >&2
    exit 1
    ;;
  *)
    load_aws_credentials
    verify_aws_credentials
    cd "$TERRAFORM_DIR"
    terraform "$cmd" "$@"
    ;;
esac
