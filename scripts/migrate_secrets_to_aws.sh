#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Migrate laptop secrets (pass + .streamlit/secrets.toml) → AWS Secrets Manager
# so EC2 instances work immediately after refresh.
#
# Targets (defaults match Terraform):
#   ams-secmon/secmon/app         — Okta, admin, STREAMLIT_APP_URL, collection settings
#   ams-secmon/secmon/trendmicro  — TRENDMICRO_*_API_TOKEN per environment
#
# Usage:
#   ./scripts/migrate_secrets_to_aws.sh
#   ./scripts/migrate_secrets_to_aws.sh --dry-run
#   STREAMLIT_APP_URL=https://secmon.example.com/ ./scripts/migrate_secrets_to_aws.sh --refresh-ec2
#
# Requires: aws CLI (AMS_1590-STG creds: pass show AWS/AMS_1590-STG), python3, pass, terraform outputs

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

SECRET_APP="${SECMON_SECRET_APP:-ams-secmon/secmon/app}"
SECRET_TM="${SECMON_SECRET_TRENDMICRO:-ams-secmon/secmon/trendmicro}"
DEPLOYMENT_CONFIG="${DEPLOYMENT_CONFIG:-$ROOT/config/deployment_config.json}"
STREAMLIT_SECRETS="${STREAMLIT_SECRETS:-$ROOT/.streamlit/secrets.toml}"
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

DRY_RUN=false
REFRESH_EC2=false
SKIP_TM=false
SKIP_APP=false

usage() {
  cat <<'EOF'
Usage: ./scripts/migrate_secrets_to_aws.sh [options]

Reads:
  - .streamlit/secrets.toml  (Okta, admin password, optional TM tokens)
  - pass TrendMicro/<env>/api_token  (per config/deployment_config.json)

Writes:
  - AWS Secrets Manager app + trendmicro secrets (JSON)

Options:
  --dry-run           Build JSON and print; do not call AWS
  --refresh-ec2       After upload, SSM: fetch secrets + restart Streamlit on ASG instances
  --skip-trendmicro   Only update app secret
  --skip-app          Only update Trend Micro secret
  --app-url URL       STREAMLIT_APP_URL (else terraform alb_dns_name or secrets.toml)
  -h, --help

Environment:
  AWS_PASS_ENTRY (default AWS/AMS_1590-STG — load creds before run, or use run-with-aws-pass pattern)
  SECMON_SECRET_APP, SECMON_SECRET_TRENDMICRO, AWS_REGION, STREAMLIT_APP_URL
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --refresh-ec2) REFRESH_EC2=true ;;
    --skip-trendmicro) SKIP_TM=true ;;
    --skip-app) SKIP_APP=true ;;
    --app-url) STREAMLIT_APP_URL="${2:?}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

die() { echo "ERROR: $*" >&2; exit 1; }

deploy_require_tools
command -v python3 >/dev/null || die "python3 required"
command -v jq >/dev/null || die "jq required"

export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
deploy_export_aws_region

if [[ "$DRY_RUN" != true ]]; then
  aws sts get-caller-identity >/dev/null 2>&1 || die "AWS credentials not active (load Pass: $AWS_PASS_ENTRY)"
fi

# Resolve STREAMLIT_APP_URL for EC2/Okta (must match Okta redirect URI exactly)
if [[ -z "${STREAMLIT_APP_URL:-}" ]]; then
  if [[ -f "$STREAMLIT_SECRETS" ]] && grep -qE '^[[:space:]]*STREAMLIT_APP_URL[[:space:]]*=' "$STREAMLIT_SECRETS" 2>/dev/null; then
    deploy_log "STREAMLIT_APP_URL will be read from $STREAMLIT_SECRETS"
  elif alb="$(deploy_tf_output alb_dns_name 2>/dev/null || true)"; then
    STREAMLIT_APP_URL="https://${alb}/"
    deploy_log "STREAMLIT_APP_URL from Terraform ALB (no value in secrets.toml): $STREAMLIT_APP_URL"
  else
    deploy_log "STREAMLIT_APP_URL not set — use --app-url or set in secrets.toml"
  fi
fi
# Only export when explicitly set (env, --app-url, or terraform fallback above).
# Do not export when URL comes from secrets.toml — Python reads the file directly.
[[ -n "${STREAMLIT_APP_URL:-}" ]] && export STREAMLIT_APP_URL
export STREAMLIT_SECRETS DEPLOYMENT_CONFIG ROOT

OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT
APP_JSON="$OUT_DIR/app-secret.json"
TM_JSON="$OUT_DIR/trendmicro-secret.json"

deploy_log "Building secret JSON from pass + $STREAMLIT_SECRETS"

python3 - <<'PY' "$APP_JSON" "$TM_JSON"
import json
import os
import re
import subprocess
import sys
from pathlib import Path

app_out, tm_out = Path(sys.argv[1]), Path(sys.argv[2])
root = Path(os.environ["ROOT"])
secrets_toml = Path(os.environ.get("STREAMLIT_SECRETS", root / ".streamlit/secrets.toml"))
deployment_config = Path(os.environ.get("DEPLOYMENT_CONFIG", root / "config/deployment_config.json"))

APP_KEYS = {
    "OKTA_DOMAIN",
    "OKTA_CLIENT_ID",
    "OKTA_CLIENT_SECRET",
    "OKTA_AUTH_SERVER_ID",
    "OKTA_SCOPE",
    "OKTA_REDIRECT_URI",
    "OKTA_STATE_SIGNING_KEY",
    "STREAMLIT_APP_URL",
    "SETTINGS_ADMIN_USER",
    "SETTINGS_ADMIN_PASSWORD",
    "SETTINGS_ADMIN_PASSWORD_BCRYPT",
    "COLLECTION_FREQUENCY",
    "COLLECTION_ENABLED",
}

def parse_toml_simple(path: Path) -> dict[str, str]:
    """Minimal TOML parser for flat key = \"value\" lines (secrets.toml)."""
    data: dict[str, str] = {}
    if not path.is_file():
        return data
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("["):
            continue
        m = re.match(r'^([A-Za-z0-9_]+)\s*=\s*"(.*)"\s*$', line)
        if m:
            key, val = m.group(1), m.group(2)
            data[key] = val.encode("utf-8").decode("unicode_escape")
        else:
            m2 = re.match(r"^([A-Za-z0-9_]+)\s*=\s*'([^']*)'\s*$", line)
            if m2:
                data[m2.group(1)] = m2.group(2)
    return data

def pass_token(env_name: str) -> str | None:
    path = f"TrendMicro/{env_name}/api_token"
    try:
        out = subprocess.run(
            ["pass", "show", path],
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    token = out.stdout.splitlines()[0].strip() if out.stdout else ""
    return token or None

def env_to_secret_key(env: str) -> str:
    return f"TRENDMICRO_{env.upper().replace('-', '_')}_API_TOKEN"

toml = parse_toml_simple(secrets_toml)
app: dict[str, str] = {}
tm: dict[str, str] = {}

for k, v in toml.items():
    if not v or v.startswith("your_") or v in ("REPLACE_ME", "paste-from-pass-migrate-script"):
        continue
    if k in APP_KEYS:
        app[k] = v.strip()
    elif k.startswith("TRENDMICRO_") and k.endswith("_API_TOKEN"):
        tm[k] = v.strip()

# Defaults / overrides
if os.environ.get("STREAMLIT_APP_URL"):
    app["STREAMLIT_APP_URL"] = os.environ["STREAMLIT_APP_URL"].strip()
if app.get("OKTA_REDIRECT_URI") and not app.get("STREAMLIT_APP_URL"):
    app["STREAMLIT_APP_URL"] = app["OKTA_REDIRECT_URI"]
if app.get("STREAMLIT_APP_URL") and not app.get("OKTA_REDIRECT_URI"):
    app["OKTA_REDIRECT_URI"] = app["STREAMLIT_APP_URL"]

app.setdefault("COLLECTION_FREQUENCY", "daily")
app.setdefault("COLLECTION_ENABLED", "true")

# Normalize Okta domain (strip scheme)
if app.get("OKTA_DOMAIN"):
    d = app["OKTA_DOMAIN"].strip()
    for prefix in ("https://", "http://"):
        if d.startswith(prefix):
            d = d[len(prefix) :]
    app["OKTA_DOMAIN"] = d.split("/")[0]

# Trend Micro from pass
if deployment_config.is_file():
    cfg = json.loads(deployment_config.read_text(encoding="utf-8"))
    for env in sorted((cfg.get("environments") or {}).keys()):
        key = env_to_secret_key(env)
        if key in tm and tm[key]:
            continue
        token = pass_token(env)
        if token:
            tm[key] = token

required_app = ("OKTA_DOMAIN", "OKTA_CLIENT_ID", "OKTA_CLIENT_SECRET", "SETTINGS_ADMIN_USER")
missing = [k for k in required_app if not app.get(k)]
if missing:
    print(
        f"WARN: app secret missing {missing} — copy .streamlit/secrets.toml.example → secrets.toml",
        file=sys.stderr,
    )

app_out.write_text(json.dumps(app, indent=2), encoding="utf-8")
tm_out.write_text(json.dumps(tm, indent=2), encoding="utf-8")
print(f"App keys: {len(app)} → {app_out}")
print(f"Trend Micro keys: {len(tm)} → {tm_out}")
if not app.get("OKTA_CLIENT_ID") and not app.get("SETTINGS_ADMIN_USER"):
    print("ERROR: app secret needs Okta or admin settings in .streamlit/secrets.toml", file=sys.stderr)
    sys.exit(1)
if not tm:
    print("WARN: trendmicro secret JSON is empty (pass entries missing?)", file=sys.stderr)
PY

echo ""
echo "=== App secret (redacted) ==="
jq 'with_entries(if .key | test("SECRET|PASSWORD|TOKEN"; "i") then .value = "***" else . end)' "$APP_JSON"
echo ""
echo "=== Trend Micro secret (keys only) ==="
jq 'keys' "$TM_JSON"

upload_secret() {
  local id="$1" file="$2"
  if [[ "$DRY_RUN" == true ]]; then
    deploy_log "[dry-run] would put-secret-value: $id"
    return 0
  fi
  deploy_log "Uploading $id"
  aws secretsmanager put-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$id" \
    --secret-string "file://$file"
}

if [[ "$SKIP_APP" != true ]]; then
  # Preserve bootstrap admin keys if not in secrets.toml (avoid wiping on Okta-only updates).
  if [[ "$DRY_RUN" != true ]] && aws secretsmanager describe-secret \
    --region "$AWS_REGION" --secret-id "$SECRET_APP" >/dev/null 2>&1; then
    EXISTING_APP="$OUT_DIR/app-secret-existing.json"
    if aws secretsmanager get-secret-value \
      --region "$AWS_REGION" \
      --secret-id "$SECRET_APP" \
      --query SecretString \
      --output text >"$EXISTING_APP" 2>/dev/null; then
      jq -s '
        .[0] as $old | .[1] as $new |
        $new + ($old | with_entries(select(.key | test("^SETTINGS_ADMIN_"))))
      ' "$EXISTING_APP" "$APP_JSON" >"$OUT_DIR/app-secret-merged.json"
      mv "$OUT_DIR/app-secret-merged.json" "$APP_JSON"
      deploy_log "Merged existing SETTINGS_ADMIN_* into app secret"
    fi
  fi
  upload_secret "$SECRET_APP" "$APP_JSON"
fi

if [[ "$SKIP_TM" != true ]] && [[ "$(jq 'length' "$TM_JSON")" -gt 0 ]]; then
  upload_secret "$SECRET_TM" "$TM_JSON"
elif [[ "$SKIP_TM" != true ]]; then
  echo "WARN: Skipping trendmicro upload (no tokens resolved)" >&2
fi

deploy_log "Secrets Manager updated."

if [[ "$REFRESH_EC2" == true ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    deploy_log "[dry-run] would refresh EC2 via SSM"
    exit 0
  fi
  ASG="$(deploy_asg_name)"
  [[ -n "$ASG" ]] || die "ASG name unknown — set SECMON_ASG_NAME or apply Terraform"

  INSTANCE_IDS="$(aws autoscaling describe-auto-scaling-groups \
    --region "$AWS_REGION" \
    --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --output text)"

  [[ -n "$INSTANCE_IDS" && "$INSTANCE_IDS" != "None" ]] || die "No InService instances in ASG: $ASG"

  deploy_log "Refreshing secrets on instances: $INSTANCE_IDS"
  CMD_ID="$(aws ssm send-command \
    --region "$AWS_REGION" \
    --document-name "AWS-RunShellScript" \
    --instance-ids $INSTANCE_IDS \
    --parameters commands="[
      \"/opt/secmon/app/scripts/ec2_fetch_secrets.sh\",
      \"systemctl restart secmon-streamlit.service\"
    ]" \
    --query 'Command.CommandId' \
    --output text)"

  deploy_log "SSM command $CMD_ID sent; check: aws ssm list-command-invocations --command-id $CMD_ID"
fi

echo ""
echo "Next steps:"
echo "  • Confirm STREAMLIT_APP_URL matches Okta redirect URI: $(jq -r '.STREAMLIT_APP_URL // "?"' "$APP_JSON")"
if [[ "$REFRESH_EC2" != true && "$DRY_RUN" != true ]]; then
  echo "  • On EC2: sudo /opt/secmon/app/scripts/ec2_fetch_secrets.sh && sudo systemctl restart secmon-streamlit"
  echo "  • Or: ./scripts/migrate_secrets_to_aws.sh --refresh-ec2"
  echo "  • Or: ./scripts/aws_deploy.sh --update --no-refresh  # then instance refresh if needed"
fi
