#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Repair Streamlit on running EC2 instances (502 / unhealthy targets) via SSM.
#
# Usage:
#   ./scripts/debug/repair_ec2_streamlit.sh
#   ./scripts/debug/repair_ec2_streamlit.sh 2.0.0

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

VERSION="${1:-$(grep '^VERSION=' "$ROOT/VERSION" | cut -d= -f2)}"
export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
deploy_export_aws_region

aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERROR: AWS credentials not active. Load pass: pass show $AWS_PASS_ENTRY" >&2
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

deploy_log "Publishing app release $VERSION to S3 (ensure repair script is on instance)"
"$ROOT/scripts/package_app_release.sh" "$VERSION" "$BUCKET"

for IID in $INSTANCE_IDS; do
  deploy_log "Repairing $IID (release $VERSION, bucket $BUCKET)"

  CMD_ID="$(aws ssm send-command \
    --region "$AWS_REGION" \
    --document-name "AWS-RunShellScript" \
    --instance-ids "$IID" \
    --comment "secmon repair streamlit $VERSION" \
    --parameters "commands=[
      \"export AWS_DEFAULT_REGION=${AWS_REGION}\",
      \"chmod +x /opt/secmon/app/scripts/ec2_repair_streamlit_remote.sh 2>/dev/null || true\",
      \"bash /opt/secmon/app/scripts/ec2_repair_streamlit_remote.sh ${VERSION} ${BUCKET}\"
    ]" \
    --query 'Command.CommandId' \
    --output text)"

  if deploy_ssm_wait_command "$CMD_ID" "$IID" 600; then
    deploy_log "Repair succeeded on $IID"
  else
    echo "ERROR: Repair failed on $IID (see SSM output above)" >&2
    exit 1
  fi
done

echo ""
deploy_log "Waiting 90s for ALB health checks (2 x 30s interval)..."
sleep 90
deploy_log "ALB target health:"
aws elbv2 describe-target-health \
  --region "$AWS_REGION" \
  --target-group-arn "$(deploy_tf_output target_group_arn)" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

ALB_DNS="$(deploy_tf_output alb_dns_name 2>/dev/null || true)"
[[ -n "$ALB_DNS" ]] && echo "" && echo "Open: http://${ALB_DNS}/"
