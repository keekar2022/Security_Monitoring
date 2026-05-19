#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Unified AWS deployment: preflight, fresh deploy, or app/metrics update.
#
# Usage:
#   ./scripts/aws_deploy.sh --verify
#   ./scripts/aws_deploy.sh --full [--auto-approve] [--infra-only] ...
#   ./scripts/aws_deploy.sh --update [version] [--metrics-only] [--with-metrics] ...

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
export TERRAFORM_DIR="${TERRAFORM_DIR:-$(deploy_default_terraform_dir)}"

MODE=""
declare -a ARGS=()

usage() {
  cat <<'EOF'
Usage: ./scripts/aws_deploy.sh --verify | --full [options] | --update [version] [options]

Modes (exactly one required):
  --verify            Preflight: tools, tfvars, artifacts, optional AWS
  --full              Fresh deploy: Terraform + app release + metrics seed + instance refresh
  --update            Periodic update: app release and/or metrics (no Terraform)

--full options:
  --auto-approve      Apply Terraform without interactive confirm
  --infra-only        Run Terraform only (no app/metrics/refresh)
  --skip-terraform    Skip Terraform (app + metrics + refresh only)
  --skip-metrics      Do not upload local data/ to S3
  --skip-refresh      Do not start ASG instance refresh
  --version VER       App release version (default: VERSION file)

--update options:
  --metrics-only      Upload local data/ to S3 and sync to EC2 via SSM (default: no instance refresh)
  --with-metrics      Also upload local data/ before app update
  --no-refresh        Default for --update: use SSM repair/sync instead of instance refresh
  --with-refresh      Opt in to ASG instance refresh (slow; use for OS AMI changes only)

Environment:
  AWS_PASS_ENTRY      Pass entry for AWS creds (default: AWS/AMS_1590-STG)
  TERRAFORM_DIR       Terraform working dir (default: terraform/envs/aws1590)
  METRICS_S3_BUCKET   Override S3 bucket (else from terraform output)

Examples:
  ./scripts/aws_deploy.sh --verify
  ./scripts/aws_deploy.sh --full --auto-approve
  ./scripts/aws_deploy.sh --full --infra-only
  ./scripts/aws_deploy.sh --update
  ./scripts/aws_deploy.sh --update 2.0.1 --with-metrics
  ./scripts/aws_deploy.sh --update --metrics-only
  ./scripts/debug/fix_aws_dashboard.sh          # recommended: app + metrics + SSM repair (no refresh)

Legacy wrappers (same behavior):
  verify_aws_deploy.sh, aws_deploy_fresh.sh, aws_deploy_update.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify|--full|--update)
      if [[ -n "$MODE" ]]; then
        echo "ERROR: specify only one of --verify, --full, --update" >&2
        exit 1
      fi
      MODE="${1#--}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      ARGS+=("$1")
      ;;
  esac
  shift
done

[[ -n "$MODE" ]] || {
  usage >&2
  exit 1
}

run_verify() {
  local TF_DIR pass fail warn
  TF_DIR="$(deploy_terraform_dir)"
  pass=0
  fail=0
  warn=0

  check() {
    local name="$1"
    shift
    if "$@"; then
      echo "OK   $name"
      pass=$((pass + 1))
    else
      echo "FAIL $name"
      fail=$((fail + 1))
    fi
  }

  warn_check() {
    local name="$1"
    shift
    if "$@"; then
      echo "OK   $name"
      pass=$((pass + 1))
    else
      echo "WARN $name"
      warn=$((warn + 1))
    fi
  }

  echo "=== Tools ==="
  check "terraform installed" command -v terraform
  check "aws CLI installed" command -v aws
  warn_check "pass installed (or set AWS_* env)" command -v pass

  echo ""
  echo "=== Terraform ==="
  check "terraform.tfvars exists" test -f "$TF_DIR/terraform.tfvars"
  check "terraform validate" bash -c "terraform -chdir='$TF_DIR' validate >/dev/null"
  check "run-with-aws-pass.sh executable" test -x "$(deploy_tf_runner)"

  echo ""
  echo "=== Application artifacts ==="
  check "app.py present" test -f "$ROOT/app.py"
  check "requirements.txt present" test -f "$ROOT/requirements.txt"
  check "package_app_release.sh" test -x "$ROOT/scripts/package_app_release.sh"
  check "push_local_metrics_to_s3.sh" test -x "$ROOT/scripts/push_local_metrics_to_s3.sh"
  check "aws_deploy.sh" test -x "$ROOT/scripts/aws_deploy.sh"
  check "systemd unit secmon-streamlit" test -f "$ROOT/deploy/systemd/secmon-streamlit.service"
  check "cron secmon-collect" test -f "$ROOT/deploy/cron/secmon-collect"
  check "ec2_daily_collect.sh" test -f "$ROOT/scripts/ec2_daily_collect.sh"

  echo ""
  echo "=== Local dashboard data ==="
  if [[ -d "$ROOT/data" ]]; then
    local jsonl_count
    jsonl_count="$(find "$ROOT/data" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$jsonl_count" -gt 0 ]]; then
      echo "OK   data/ has $jsonl_count JSONL file(s) ready for S3 seed"
      pass=$((pass + 1))
    else
      echo "WARN data/ exists but no .jsonl files (dashboard may be empty until first collect)"
      warn=$((warn + 1))
    fi
  else
    echo "WARN data/ directory missing"
    warn=$((warn + 1))
  fi

  echo ""
  echo "=== AWS credentials (optional if not applying yet) ==="
  if aws sts get-caller-identity >/dev/null 2>&1; then
    echo "OK   AWS credentials valid"
    pass=$((pass + 1))
    local id
    id="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
    [[ -n "$id" ]] && echo "     Account: $id"
    if terraform -chdir="$TF_DIR" output s3_bucket_name >/dev/null 2>&1; then
      echo "OK   Terraform state has outputs (stack already applied)"
      pass=$((pass + 1))
      echo "     bucket=$(terraform -chdir="$TF_DIR" output -raw s3_bucket_name 2>/dev/null || echo '?')"
      echo "     alb=$(terraform -chdir="$TF_DIR" output -raw alb_dns_name 2>/dev/null || echo '?')"
    else
      echo "     (Terraform not applied yet — expected for first deploy)"
    fi
  else
    echo "WARN AWS credentials not active (run pass / aws sso login before apply)"
    warn=$((warn + 1))
  fi

  echo ""
  echo "=== Go collector (optional build check) ==="
  if command -v go >/dev/null 2>&1; then
    if make -C "$ROOT/go" collector >/dev/null 2>&1; then
      echo "OK   go/bin/collector builds"
      pass=$((pass + 1))
    else
      echo "FAIL go collector build"
      fail=$((fail + 1))
    fi
  else
    echo "WARN go not installed (package_app_release.sh will need go on PATH)"
    warn=$((warn + 1))
  fi

  echo ""
  echo "Result: $pass passed, $fail failed, $warn warnings"
  echo ""
  echo "Account:       AMS_1590-STG (pass show AWS/AMS_1590-STG)"
  echo "Fresh deploy:  ./scripts/aws_deploy.sh --full"
  echo "App update:    ./scripts/aws_deploy.sh --update"
  echo "Metrics only:  ./scripts/aws_deploy.sh --update --metrics-only"
  echo "Stable fix:    ./scripts/debug/fix_aws_dashboard.sh"
  echo "See: docs/AWS_DEPLOYMENT.md"

  [[ "$fail" -eq 0 ]]
}

run_full() {
  local AUTO_APPROVE=false SKIP_TERRAFORM=false INFRA_ONLY=false
  local SKIP_METRICS=false SKIP_REFRESH=false VERSION=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --auto-approve) AUTO_APPROVE=true ;;
      --infra-only) INFRA_ONLY=true ;;
      --skip-terraform) SKIP_TERRAFORM=true ;;
      --skip-metrics) SKIP_METRICS=true ;;
      --skip-refresh) SKIP_REFRESH=true ;;
      --version) VERSION="${2:?--version requires value}"; shift ;;
      *)
        echo "Unknown option for --full: $1" >&2
        exit 1
        ;;
    esac
    shift
  done

  if [[ "$INFRA_ONLY" == true && "$SKIP_TERRAFORM" == true ]]; then
    echo "ERROR: --infra-only and --skip-terraform conflict" >&2
    exit 1
  fi

  deploy_require_tools
  deploy_ensure_tfvars
  deploy_load_aws_from_pass "${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
  deploy_export_aws_region

  local TF_RUN BUCKET
  TF_RUN="$(deploy_tf_runner)"
  [[ -x "$TF_RUN" ]] || chmod +x "$TF_RUN"

  VERSION="${VERSION:-$(grep '^VERSION=' "$ROOT/VERSION" | cut -d= -f2)}"

  run_terraform_apply() {
    deploy_log "Terraform init"
    "$TF_RUN" init -upgrade

    deploy_log "Terraform plan"
    if [[ "$AUTO_APPROVE" == true ]]; then
      "$TF_RUN" apply -auto-approve
    else
      "$TF_RUN" plan -out=tfplan
      echo ""
      read -r -p "Apply this plan? [y/N] " confirm
      confirm="$(printf '%s' "$confirm" | tr '[:upper:]' '[:lower:]')"
      if [[ "$confirm" != "y" ]]; then
        deploy_log "Aborted. Plan saved as $(deploy_terraform_dir)/tfplan"
        exit 0
      fi
      "$TF_RUN" apply tfplan
    fi
  }

  if [[ "$SKIP_TERRAFORM" != true ]]; then
    run_terraform_apply
  else
    deploy_log "Skipping Terraform (--skip-terraform)"
  fi

  if [[ "$INFRA_ONLY" == true ]]; then
    deploy_log "Infra-only complete. Next steps:"
    echo "  1. Populate Secrets Manager (see docs/AWS_DEPLOYMENT.md)"
    echo "  2. Re-run: ./scripts/aws_deploy.sh --full --skip-terraform"
    "$TF_RUN" output 2>/dev/null || true
    exit 0
  fi

  BUCKET="$(deploy_s3_bucket)"
  [[ -n "$BUCKET" ]] || {
    echo "ERROR: S3 bucket unknown — complete Terraform apply first." >&2
    exit 1
  }

  deploy_log "Publishing app release $VERSION to s3://$BUCKET/"
  "$ROOT/scripts/package_app_release.sh" "$VERSION" "$BUCKET"

  if [[ "$SKIP_METRICS" != true ]]; then
    deploy_log "Uploading local dashboard data to S3"
    DATA_DIR="$ROOT/data" METRICS_S3_BUCKET="$BUCKET" \
      "$ROOT/scripts/push_local_metrics_to_s3.sh"
  else
    deploy_log "Skipping metrics upload (--skip-metrics)"
  fi

  if [[ "$SKIP_REFRESH" != true ]]; then
    deploy_instance_refresh
  else
    deploy_log "Skipping instance refresh (--skip-refresh)"
  fi

  deploy_log "Fresh deployment steps finished."
  echo ""
  echo "Post-deploy checklist:"
  echo "  • Secrets Manager: ams-secmon/secmon/app and .../trendmicro (see docs/AWS_DEPLOYMENT.md)"
  echo "  • Okta redirect URI → https://<your-alb-domain>/"
  echo "  • Verify: ALB health, SSM session, sudo /opt/secmon/app/scripts/ec2_daily_collect.sh"
  echo ""
  "$TF_RUN" output 2>/dev/null || terraform -chdir="$TERRAFORM_DIR" output
}

run_update() {
  local METRICS_ONLY=false NO_REFRESH=true WITH_REFRESH=false SYNC_METRICS=false VERSION=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --metrics-only) METRICS_ONLY=true ;;
      --with-metrics) SYNC_METRICS=true ;;
      --no-refresh) NO_REFRESH=true ;;
      --with-refresh) WITH_REFRESH=true; NO_REFRESH=false ;;
      *)
        if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
          VERSION="$1"
        else
          echo "Unknown option for --update: $1" >&2
          exit 1
        fi
        ;;
    esac
    shift
  done

  deploy_require_tools
  deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
  deploy_export_aws_region
  deploy_log "AWS region: $AWS_REGION"

  local BUCKET
  BUCKET="$(deploy_s3_bucket)"
  [[ -n "$BUCKET" ]] || {
    echo "ERROR: Set METRICS_S3_BUCKET or ensure Terraform state has s3_bucket_name output." >&2
    exit 1
  }

  if [[ "$METRICS_ONLY" == true ]]; then
    deploy_log "Metrics-only update (SSM sync to EC2; no instance refresh unless --with-refresh)"
    DATA_DIR="$ROOT/data" METRICS_S3_BUCKET="$BUCKET" \
      "$ROOT/scripts/push_local_metrics_to_s3.sh"
    if [[ "$WITH_REFRESH" == true ]]; then
      deploy_instance_refresh
    else
      "$ROOT/scripts/debug/sync_ec2_metrics_from_s3.sh"
    fi
    exit 0
  fi

  VERSION="${VERSION:-$(grep '^VERSION=' "$ROOT/VERSION" | cut -d= -f2)}"

  if [[ "$WITH_REFRESH" == true ]]; then
    deploy_log "Publishing app release $VERSION (instance refresh)"
    "$ROOT/scripts/package_app_release.sh" "$VERSION" "$BUCKET"
    if [[ "$SYNC_METRICS" == true ]]; then
      DATA_DIR="$ROOT/data" METRICS_S3_BUCKET="$BUCKET" \
        "$ROOT/scripts/push_local_metrics_to_s3.sh"
    fi
    deploy_instance_refresh
    deploy_log "Update complete (refreshed instances)."
    exit 0
  fi

  deploy_log "In-place update via SSM (recommended): release $VERSION"
  if [[ "$SYNC_METRICS" == true ]]; then
    DATA_DIR="$ROOT/data" METRICS_S3_BUCKET="$BUCKET" \
      "$ROOT/scripts/push_local_metrics_to_s3.sh"
  fi
  "$ROOT/scripts/debug/repair_ec2_streamlit.sh" "$VERSION"
  deploy_log "Update complete. Use --with-refresh only for OS AMI / launch template changes."
}

case "$MODE" in
  verify) run_verify ;;
  full) run_full "${ARGS[@]+"${ARGS[@]}"}" ;;
  update) run_update "${ARGS[@]+"${ARGS[@]}"}" ;;
  *)
    echo "ERROR: unknown mode: $MODE" >&2
    exit 1
    ;;
esac
