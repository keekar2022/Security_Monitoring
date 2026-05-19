#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Package app tree and upload to S3 releases/<version>/ for EC2 bootstrap.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

VERSION="${1:-$(grep '^VERSION=' "$ROOT/VERSION" | cut -d= -f2)}"
BUCKET="${2:?Usage: $0 [version] <s3-bucket>}"
STAGING="${TMPDIR:-/tmp}/secmon-release-$$"
DEST="s3://${BUCKET}/releases/${VERSION}/"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v aws >/dev/null || die "aws CLI required"
export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
deploy_export_aws_region
[[ -f "$ROOT/app.py" ]] || die "Run from Security_Monitoring repo root"

echo "Building Go collectors and EC2 collector..."
make -C "$ROOT/go" collector

rm -rf "$STAGING"
mkdir -p "$STAGING"

RSYNC_EXCLUDES=(
  --exclude '.git'
  --exclude '.env'
  --exclude '.streamlit/credentials.toml'
  --exclude '.streamlit/secrets.toml'
  --exclude 'data/*.jsonl'
  --exclude 'terraform/.terraform'
  --exclude 'terraform/.lambda'
  --exclude '.cursor'
  --exclude '.run'
  --exclude '.DS_Store'
  --exclude 'scripts/debug'
  --exclude '__pycache__'
  --exclude 'venv'
  --exclude '.venv'
  --exclude 'node_modules'
)

rsync -a "${RSYNC_EXCLUDES[@]}" "$ROOT/" "$STAGING/"

# shellcheck source=lib/chmod_release.sh
source "$ROOT/scripts/lib/chmod_release.sh"
secmon_chmod_release_tree "$STAGING"

echo "Uploading to $DEST"
aws s3 sync "$STAGING/" "$DEST" --region "$AWS_REGION" --delete
# Remove accidental .venv uploads from older packages (keeps EC2 sync fast).
aws s3 rm "$DEST.venv/" --region "$AWS_REGION" --recursive 2>/dev/null || true
echo "Release $VERSION published to $DEST"

rm -rf "$STAGING"
