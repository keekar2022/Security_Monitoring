#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Run ON EC2 (via SSM or shell) to fix unhealthy ALB targets / 502.
# Usage: ec2_repair_streamlit_remote.sh [version] [s3_bucket]
set -uo pipefail

VERSION="${1:-$(grep -m1 '^VERSION=' /opt/secmon/app/VERSION 2>/dev/null | cut -d= -f2)}"
BUCKET="${2:-$(grep -m1 '^METRICS_S3_BUCKET=' /opt/secmon/deploy.env 2>/dev/null | cut -d= -f2)}"
REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-us-east-1}}"
export AWS_DEFAULT_REGION="$REGION"

INSTALL_ROOT="/opt/secmon"
APP_ROOT="$INSTALL_ROOT/app"
DATA_DIR="$INSTALL_ROOT/data"
VENV="$INSTALL_ROOT/venv"
ENV_DIR="/run/secmon"

log() { echo "[secmon-repair] $*"; }

[[ -n "$VERSION" && -n "$BUCKET" ]] || {
  log "ERROR: need version and bucket (args or deploy.env / VERSION file)"
  exit 1
}

log "Repair release=$VERSION bucket=$BUCKET region=$REGION"

command -v aws >/dev/null || { log "ERROR: aws CLI missing"; exit 1; }
command -v jq >/dev/null || dnf -y install jq
command -v python3.11 >/dev/null || dnf -y install python3.11 python3.11-pip python3.11-devel gcc

mkdir -p "$ENV_DIR" "$DATA_DIR" /var/log/secmon
chmod 700 "$ENV_DIR" 2>/dev/null || true

log "S3 sync app release (exclude local .venv artifacts)"
aws s3 sync "s3://${BUCKET}/releases/${VERSION}/" "$APP_ROOT/" --region "$REGION" --delete \
  --exclude '.venv/*' --exclude 'venv/*'
rm -rf "$APP_ROOT/.venv" "$APP_ROOT/venv" 2>/dev/null || true

log "S3 sync metrics data"
aws s3 sync "s3://${BUCKET}/data/" "$DATA_DIR/" --region "$REGION" || true

if [[ ! -f "$APP_ROOT/app.py" ]]; then
  log "ERROR: app.py missing after sync — check s3://$BUCKET/releases/$VERSION/"
  exit 1
fi

log "chmod +x scripts and Go binaries"
find "$APP_ROOT/scripts" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
[[ -d "$APP_ROOT/go/bin" ]] && chmod +x "$APP_ROOT/go/bin/"* 2>/dev/null || true

cat > "$INSTALL_ROOT/deploy.env" <<EOF
METRICS_S3_BUCKET=$BUCKET
DATA_DIR=$DATA_DIR
AWS_DEFAULT_REGION=$REGION
SECMON_COLLECTION_MODE=ec2
USE_PASS=false
COLLECTOR_NON_FATAL=true
EOF
chmod 644 "$INSTALL_ROOT/deploy.env"

log "Python venv + requirements"
python3.11 -m venv "$VENV" 2>/dev/null || true
"$VENV/bin/pip" install -q --upgrade pip
if ! "$VENV/bin/pip" install -q -r "$APP_ROOT/requirements.txt"; then
  log "WARN: pip install failed — retrying with output:"
  "$VENV/bin/pip" install -r "$APP_ROOT/requirements.txt" || true
fi

for unit in secmon-streamlit.service secmon-fetch-secrets.service; do
  if [[ -f "$APP_ROOT/deploy/systemd/$unit" ]]; then
    cp "$APP_ROOT/deploy/systemd/$unit" "/etc/systemd/system/$unit"
  fi
done

if [[ -f "$APP_ROOT/deploy/cron/secmon-collect" ]]; then
  mkdir -p /etc/cron.d
  cp "$APP_ROOT/deploy/cron/secmon-collect" /etc/cron.d/secmon-collect
  chmod 644 /etc/cron.d/secmon-collect
fi

if [[ -x "$APP_ROOT/scripts/ec2_fetch_secrets.sh" ]]; then
  log "Refresh secrets"
  SECMON_DEPLOY_ENV="$INSTALL_ROOT/deploy.env" "$APP_ROOT/scripts/ec2_fetch_secrets.sh" || log "WARN: ec2_fetch_secrets failed"
else
  log "WARN: ec2_fetch_secrets.sh missing"
fi

systemctl daemon-reload
systemctl enable secmon-fetch-secrets.service secmon-streamlit.service 2>/dev/null || true
systemctl restart secmon-fetch-secrets.service 2>/dev/null || true
systemctl restart secmon-streamlit.service

log "Waiting for Streamlit on :8501"
for _i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:8501/_stcore/health" >/dev/null 2>&1; then
    log "OK: Streamlit healthy"
    systemctl is-active secmon-streamlit.service || true
    exit 0
  fi
  sleep 10
done

log "ERROR: Streamlit not healthy after 300s"
systemctl status secmon-streamlit.service --no-pager || true
journalctl -u secmon-streamlit -n 50 --no-pager || true
tail -50 /var/log/secmon/streamlit.log 2>/dev/null || true
exit 1
