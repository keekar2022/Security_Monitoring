#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Quick health check for AMS_1590-STG Security Monitoring stack.
# Usage: ./scripts/debug/diagnose_aws_deploy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
deploy_export_aws_region

TF_DIR="$(deploy_terraform_dir)"
die() { echo "ERROR: $*" >&2; exit 1; }

aws sts get-caller-identity >/dev/null 2>&1 || die "AWS credentials not active (Pass: $AWS_PASS_ENTRY)"

ALB_DNS="$(deploy_tf_output alb_dns_name)" || die "Run terraform apply first"
TG_ARN="$(deploy_tf_output target_group_arn)" || true
ASG="$(deploy_asg_name)" || true

echo "=== Security Monitoring deploy diagnostics ==="
echo "Region:  $AWS_REGION"
echo "ALB:     http://${ALB_DNS}/"
echo ""

echo "--- Target group health ---"
if [[ -n "${TG_ARN:-}" ]]; then
  aws elbv2 describe-target-health --region "$AWS_REGION" --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table || true
else
  echo "  (target group ARN not found)"
fi

echo ""
echo "--- ASG ---"
if [[ -n "${ASG:-}" ]]; then
  aws autoscaling describe-auto-scaling-groups --region "$AWS_REGION" \
    --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:Instances[*].[InstanceId,LifecycleState,HealthStatus]}' \
    --output yaml || true
fi

echo ""
echo "--- ALB listeners ---"
aws elbv2 describe-listeners --region "$AWS_REGION" \
  --load-balancer-arn "$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --names ams-secmon-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)" \
  --query 'Listeners[*].[Port,Protocol,DefaultActions[0].Type]' \
  --output table 2>/dev/null || echo "  (could not list listeners)"

echo ""
echo "--- ALB security group ingress ---"
ALB_SG="$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --names ams-secmon-alb --query 'LoadBalancers[0].SecurityGroups[0]' --output text 2>/dev/null || true)"
if [[ -n "$ALB_SG" && "$ALB_SG" != "None" ]]; then
  aws ec2 describe-security-groups --region "$AWS_REGION" --group-ids "$ALB_SG" \
    --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort,IpRanges[0].CidrIp]' \
    --output table
fi

echo ""
MY_IP="$(curl -sS --max-time 5 https://ifconfig.me 2>/dev/null || curl -sS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
[[ -n "$MY_IP" ]] && echo "Your public IP: ${MY_IP}/32 (must be in default_allowed_cidr_blocks in terraform.tfvars)"
echo ""
echo "Use HTTP (not HTTPS) until ACM is configured:"
echo "  http://${ALB_DNS}/"
echo ""
echo "--- S3 metrics (dashboard JSONL) ---"
BUCKET="$(deploy_s3_bucket 2>/dev/null || true)"
if [[ -n "${BUCKET:-}" ]]; then
  for f in container_vulnerability_metrics.jsonl endpoint_vulnerability_metrics.jsonl endpoint_inventory_metrics.jsonl; do
    sz="$(aws s3 ls "s3://${BUCKET}/data/$f" --region "$AWS_REGION" 2>/dev/null | awk '{print $3}' || true)"
    if [[ -n "$sz" ]]; then
      echo "  $f: ${sz} bytes"
    else
      echo "  $f: MISSING (run ./scripts/push_local_metrics_to_s3.sh)"
    fi
  done
  legacy="$(aws s3 ls "s3://${BUCKET}/data/server_vulnerabilities_legacy/" --region "$AWS_REGION" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  server_vulnerabilities_legacy/: ${legacy:-0} object(s)"
else
  echo "  (S3 bucket unknown)"
fi

echo ""
if aws elbv2 describe-target-health --region "$AWS_REGION" --target-group-arn "${TG_ARN:-}" \
  --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`]' --output text 2>/dev/null | grep -q .; then
  echo "Unhealthy targets — repair (loads AWS creds from pass automatically):"
  echo "  ./scripts/debug/repair_ec2_streamlit.sh"
fi
