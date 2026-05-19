#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Shared helpers for AWS EC2 deployment scripts (Terraform + S3 + ASG).

# Default AWS account: AMS_1590-STG (pass: AWS/AMS_1590-STG)
deploy_default_pass_entry() {
  echo "AWS/AMS_1590-STG"
}

deploy_default_terraform_dir() {
  echo "$(deploy_repo_root)/terraform/envs/aws1590"
}

deploy_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  cd "$(dirname "$script_dir")/.." && pwd
}

deploy_terraform_dir() {
  echo "${TERRAFORM_DIR:-$(deploy_default_terraform_dir)}"
}

deploy_tf_runner() {
  echo "$(deploy_repo_root)/terraform/run-with-aws-pass.sh"
}

deploy_ensure_tfvars() {
  local tfdir
  tfdir="$(deploy_terraform_dir)"
  if [[ ! -f "$tfdir/terraform.tfvars" ]]; then
    echo "ERROR: $tfdir/terraform.tfvars not found." >&2
    echo "  cp $tfdir/terraform.tfvars.example $tfdir/terraform.tfvars" >&2
    echo "  Edit s3_bucket_name, default_allowed_cidr_blocks, image_factory_owner_id" >&2
    return 1
  fi
}

deploy_require_tools() {
  command -v terraform >/dev/null || {
    echo "ERROR: terraform not in PATH" >&2
    return 1
  }
  command -v aws >/dev/null || {
    echo "ERROR: aws CLI not in PATH" >&2
    return 1
  }
}

deploy_tf_output() {
  local name="$1"
  local tfdir val
  tfdir="$(deploy_terraform_dir)"
  val="$(terraform -chdir="$tfdir" output -raw "$name" 2>/dev/null)" || return 1
  # Reject empty or multi-line (terraform warnings on stdout when state has no outputs)
  [[ -n "$val" && "$val" != *$'\n'* && "$val" != *'Warning:'* ]] || return 1
  printf '%s' "$val"
}

deploy_s3_bucket() {
  if [[ -n "${METRICS_S3_BUCKET:-}" ]]; then
    echo "$METRICS_S3_BUCKET"
    return 0
  fi
  deploy_tf_output s3_bucket_name
}

deploy_asg_name() {
  if [[ -n "${SECMON_ASG_NAME:-}" ]]; then
    echo "$SECMON_ASG_NAME"
    return 0
  fi
  deploy_tf_output asg_name
}

# Active refresh id (Pending/InProgress) or empty.
deploy_active_instance_refresh_id() {
  local asg="$1"
  aws autoscaling describe-instance-refreshes \
    --region "$AWS_REGION" \
    --auto-scaling-group-name "$asg" \
    --max-records 10 \
    --query 'InstanceRefreshes[?Status==`Pending` || Status==`InProgress`] | [0].InstanceRefreshId' \
    --output text 2>/dev/null | tr -d '\r' | sed '/^None$/d'
}

# Wait until no Pending/InProgress refresh (so start-instance-refresh can run).
deploy_wait_instance_refresh() {
  local asg="$1"
  local timeout="${2:-${DEPLOY_REFRESH_WAIT_SEC:-1800}}"
  local poll="${DEPLOY_REFRESH_POLL_SEC:-30}"
  local elapsed=0
  local rid status pct

  rid="$(deploy_active_instance_refresh_id "$asg")"
  [[ -n "$rid" ]] || return 0

  deploy_log "Waiting for instance refresh $rid to finish (timeout ${timeout}s)..."
  while [[ "$elapsed" -lt "$timeout" ]]; do
    rid="$(deploy_active_instance_refresh_id "$asg")"
    [[ -n "$rid" ]] || {
      deploy_log "Previous instance refresh completed."
      return 0
    }
    read -r status pct reason _ <<<"$(aws autoscaling describe-instance-refreshes \
      --region "$AWS_REGION" \
      --auto-scaling-group-name "$asg" \
      --instance-refresh-ids "$rid" \
      --query 'InstanceRefreshes[0].[Status,PercentageComplete,StatusReason]' \
      --output text 2>/dev/null || echo '? ? ?')"
    status="${status:-?}"
    pct="${pct:-?}"
    deploy_log "  refresh $rid: status=$status complete=${pct}% (${elapsed}s)"
    [[ -n "${reason:-}" && "$reason" != "None" && "$reason" != "?" ]] && deploy_log "    reason: $reason"
    if [[ "$pct" == "100" && "$status" == "InProgress" ]]; then
      deploy_log "    (100% = instances launched; still waiting InstanceWarmup + ELB healthy — often 7–10 min)"
    fi
    sleep "$poll"
    elapsed=$((elapsed + poll))
  done
  echo "ERROR: Timed out waiting for instance refresh on $asg" >&2
  echo "  Check: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $asg --region $AWS_REGION" >&2
  return 1
}

deploy_refresh_preferences() {
  local asg="$1"
  local warmup="${2:-600}"
  local desired max_size min_healthy
  desired="$(aws autoscaling describe-auto-scaling-groups \
    --region "$AWS_REGION" \
    --auto-scaling-group-names "$asg" \
    --query 'AutoScalingGroups[0].DesiredCapacity' \
    --output text 2>/dev/null || echo "1")"
  max_size="$(aws autoscaling describe-auto-scaling-groups \
    --region "$AWS_REGION" \
    --auto-scaling-group-names "$asg" \
    --query 'AutoScalingGroups[0].MaxSize' \
    --output text 2>/dev/null || echo "1")"
  min_healthy=50
  if [[ "${desired:-1}" -le 1 && "${max_size:-1}" -ge 2 ]]; then
    min_healthy=100
  fi
  # stdout only — valid JSON for aws autoscaling start-instance-refresh --preferences
  printf '{"MinHealthyPercentage":%s,"InstanceWarmup":%s}' "$min_healthy" "$warmup"
}

deploy_start_instance_refresh() {
  local asg="$1"
  local warmup="${2:-${DEPLOY_REFRESH_WARMUP_SEC:-600}}"
  local err_file rid prefs

  prefs="$(deploy_refresh_preferences "$asg" "$warmup")"
  deploy_log "Instance refresh preferences: $prefs"
  if [[ "$(jq -r '.MinHealthyPercentage' <<<"$prefs" 2>/dev/null)" == "100" ]]; then
    deploy_log "MinHealthyPercentage=100 (keep old instance until new target is healthy)"
  fi
  deploy_log "InstanceWarmup=${warmup}s (bootstrap + pip + Streamlit must pass /_stcore/health)"
  err_file="$(mktemp "${TMPDIR:-/tmp}/secmon-refresh.XXXXXX")"
  if aws autoscaling start-instance-refresh \
    --region "$AWS_REGION" \
    --auto-scaling-group-name "$asg" \
    --preferences "$prefs" \
    2>"$err_file"; then
    rid="$(aws autoscaling describe-instance-refreshes \
      --region "$AWS_REGION" \
      --auto-scaling-group-name "$asg" \
      --max-records 1 \
      --query 'InstanceRefreshes[0].InstanceRefreshId' \
      --output text 2>/dev/null || true)"
    deploy_log "Instance refresh started${rid:+: $rid}"
    rm -f "$err_file"
    return 0
  fi

  if grep -q 'InstanceRefreshInProgress' "$err_file" 2>/dev/null; then
    deploy_log "Another instance refresh is in progress — waiting, then retrying..."
    rm -f "$err_file"
    deploy_wait_instance_refresh "$asg" || return 1
    aws autoscaling start-instance-refresh \
      --region "$AWS_REGION" \
      --auto-scaling-group-name "$asg" \
      --preferences "$prefs" >/dev/null
    rid="$(aws autoscaling describe-instance-refreshes \
      --region "$AWS_REGION" \
      --auto-scaling-group-name "$asg" \
      --max-records 1 \
      --query 'InstanceRefreshes[0].InstanceRefreshId' \
      --output text 2>/dev/null || true)"
    deploy_log "Instance refresh started${rid:+: $rid}"
    return 0
  fi

  cat "$err_file" >&2
  rm -f "$err_file"
  return 1
}

deploy_instance_refresh() {
  local warmup="${1:-${DEPLOY_REFRESH_WARMUP_SEC:-600}}"
  local asg
  asg="$(deploy_asg_name)"
  [[ -n "$asg" ]] || {
    echo "ERROR: Could not resolve ASG name (apply Terraform or set SECMON_ASG_NAME)" >&2
    return 1
  }
  deploy_export_aws_region
  deploy_log "Instance refresh on ASG: $asg (region: $AWS_REGION)"
  deploy_wait_instance_refresh "$asg" || return 1
  deploy_start_instance_refresh "$asg" "$warmup"
}

deploy_log() {
  echo "[deploy] $*"
}

# Poll SSM Run Command and print stdout/stderr (requires AWS creds in env).
deploy_ssm_wait_command() {
  local cmd_id="$1"
  local instance_id="$2"
  local max_wait="${3:-600}"
  local poll=10
  local elapsed=0
  local status

  deploy_log "Waiting for SSM command $cmd_id on $instance_id (max ${max_wait}s)..."
  while [[ "$elapsed" -lt "$max_wait" ]]; do
    status="$(aws ssm get-command-invocation \
      --region "$AWS_REGION" \
      --command-id "$cmd_id" \
      --instance-id "$instance_id" \
      --query 'Status' \
      --output text 2>/dev/null || echo Pending)"
    case "$status" in
      Success|Failed|Cancelled|TimedOut|Cancelling)
        break
        ;;
      *)
        sleep "$poll"
        elapsed=$((elapsed + poll))
        ;;
    esac
  done

  status="$(aws ssm get-command-invocation \
    --region "$AWS_REGION" \
    --command-id "$cmd_id" \
    --instance-id "$instance_id" \
    --query 'Status' \
    --output text 2>/dev/null || echo Unknown)"

  echo ""
  echo "=== SSM status: $status ==="
  aws ssm get-command-invocation \
    --region "$AWS_REGION" \
    --command-id "$cmd_id" \
    --instance-id "$instance_id" \
    --query 'StandardOutputContent' \
    --output text 2>/dev/null | tail -80

  local err
  err="$(aws ssm get-command-invocation \
    --region "$AWS_REGION" \
    --command-id "$cmd_id" \
    --instance-id "$instance_id" \
    --query 'StandardErrorContent' \
    --output text 2>/dev/null || true)"
  if [[ -n "$err" ]]; then
    echo "--- stderr ---"
    echo "$err" | tail -40
  fi

  [[ "$status" == "Success" ]]
}

# Load AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN from pass (if available).
deploy_aws_region() {
  if [[ -n "${AWS_REGION:-}" ]]; then
    printf '%s' "$AWS_REGION"
    return 0
  fi
  if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
    printf '%s' "$AWS_DEFAULT_REGION"
    return 0
  fi
  local tfvars region
  tfvars="$(deploy_terraform_dir)/terraform.tfvars"
  if [[ -f "$tfvars" ]]; then
    region="$(grep -E '^[[:space:]]*aws_region[[:space:]]*=' "$tfvars" | head -1 \
      | sed -E 's/^[^=]*=[[:space:]]*"([^"]+)".*/\1/')"
    if [[ -n "$region" ]]; then
      printf '%s' "$region"
      return 0
    fi
  fi
  printf '%s' "us-east-1"
}

deploy_export_aws_region() {
  export AWS_REGION="$(deploy_aws_region)"
  export AWS_DEFAULT_REGION="$AWS_REGION"
}

deploy_load_aws_from_pass() {
  local entry="${1:-$(deploy_default_pass_entry)}"
  command -v pass >/dev/null 2>&1 || return 0
  while IFS= read -r line; do
    if [[ $line =~ ^(aws_[a-z_]+)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      case "$key" in
        aws_access_key_id) export AWS_ACCESS_KEY_ID="$val" ;;
        aws_secret_access_key) export AWS_SECRET_ACCESS_KEY="$val" ;;
        aws_session_token) export AWS_SESSION_TOKEN="$val" ;;
        aws_region) export AWS_REGION="$val" ;;
      esac
    fi
  done < <(pass show "$entry" 2>/dev/null || true)
  deploy_export_aws_region
}

deploy_aws_cli() {
  deploy_export_aws_region
  aws --region "$AWS_REGION" "$@"
}
