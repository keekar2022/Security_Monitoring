#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Pull s3://<bucket>/data/ onto running EC2 instances (no instance refresh).
# Use after: ./scripts/push_local_metrics_to_s3.sh
#
# Usage: ./scripts/debug/sync_ec2_metrics_from_s3.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
deploy_export_aws_region

aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERROR: AWS credentials not active (pass show $AWS_PASS_ENTRY)" >&2
  exit 1
}

BUCKET="$(deploy_s3_bucket)" || { echo "ERROR: S3 bucket unknown" >&2; exit 1; }
ASG="$(deploy_asg_name)" || { echo "ERROR: ASG unknown" >&2; exit 1; }

INSTANCE_IDS="$(aws autoscaling describe-auto-scaling-groups \
  --region "$AWS_REGION" \
  --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
  --output text)"

[[ -n "$INSTANCE_IDS" && "$INSTANCE_IDS" != "None" ]] || {
  echo "ERROR: No InService instances in $ASG" >&2
  exit 1
}

deploy_log "S3 metrics: s3://${BUCKET}/data/ → /opt/secmon/data/ on: $INSTANCE_IDS"

for IID in $INSTANCE_IDS; do
  CMD_ID="$(aws ssm send-command \
    --region "$AWS_REGION" \
    --document-name "AWS-RunShellScript" \
    --instance-ids "$IID" \
    --comment "secmon sync metrics from S3" \
    --parameters "commands=[
      \"export AWS_DEFAULT_REGION=${AWS_REGION}\",
      \"aws s3 sync s3://${BUCKET}/data/ /opt/secmon/data/ --region ${AWS_REGION}\",
      \"echo '--- JSONL line counts ---'\",
      \"wc -l /opt/secmon/data/container_vulnerability_metrics.jsonl /opt/secmon/data/endpoint_vulnerability_metrics.jsonl /opt/secmon/data/endpoint_inventory_metrics.jsonl 2>/dev/null || true\",
      \"systemctl restart secmon-streamlit.service\"
    ]" \
    --query 'Command.CommandId' \
    --output text)"

  if deploy_ssm_wait_command "$CMD_ID" "$IID" 300; then
    deploy_log "Sync OK on $IID — reload dashboard (or use Reload data on each tab)"
  else
    echo "ERROR: Sync failed on $IID" >&2
    exit 1
  fi
done
