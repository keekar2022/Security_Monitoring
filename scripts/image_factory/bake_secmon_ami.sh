#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Bake Security Monitoring Python venv into an EC2 instance BEFORE creating a custom AMI
# (Image Factory / golden AMI workflow). New instances skip pip install on boot.
#
# Run on a throwaway EC2 (Amazon Linux 2023) with this repo or requirements.txt available:
#   sudo ./scripts/image_factory/bake_secmon_ami.sh
#
# Then create AMI from the instance (AWS Console or create-image), update
# image_factory_amazon_linux_ami_us_east_1 in terraform.tfvars, and instance refresh.

set -euo pipefail

INSTALL_ROOT="${SECMON_INSTALL_ROOT:-/opt/secmon}"
VENV="$INSTALL_ROOT/venv"
REQ="${SECMON_REQUIREMENTS:-}"

if [[ -z "$REQ" ]]; then
  if [[ -f /opt/secmon/app/requirements.txt ]]; then
    REQ=/opt/secmon/app/requirements.txt
  elif [[ -f "$(dirname "$0")/../../requirements.txt" ]]; then
    REQ="$(cd "$(dirname "$0")/../.." && pwd)/requirements.txt"
  else
    echo "ERROR: requirements.txt not found" >&2
    exit 1
  fi
fi

echo "[bake] Installing OS packages"
dnf -y install python3.11 python3.11-pip python3.11-devel gcc

mkdir -p "$INSTALL_ROOT" /var/log/secmon

echo "[bake] Creating venv at $VENV"
python3.11 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install -r "$REQ"

# Marker for user-data bootstrap
date -u +%Y-%m-%dT%H:%M:%SZ >"$VENV/.secmon-baked"
echo "requirements=$REQ" >>"$VENV/.secmon-baked"

# Pre-install systemd unit templates if app tree exists
for unit in secmon-streamlit.service secmon-fetch-secrets.service; do
  if [[ -f "$INSTALL_ROOT/app/deploy/systemd/$unit" ]]; then
    cp "$INSTALL_ROOT/app/deploy/systemd/$unit" "/etc/systemd/system/$unit"
  fi
done
systemctl daemon-reload || true

echo "[bake] Done. Verify: $VENV/bin/streamlit version"
echo "[bake] Create AMI from this instance, then set image_factory_amazon_linux_ami_us_east_1 in tfvars."
