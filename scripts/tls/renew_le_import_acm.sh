#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Import Let's Encrypt certificate into ACM for ALB (ACM issues certs — import only).
#
# Step 1 — obtain cert (once per renewal, ~60 days):
#   certbot certonly --manual --preferred-challenges dns -d secmon.example.com
#   (add TXT records when prompted; certs land in /etc/letsencrypt/live/secmon.example.com/)
#
# Step 2 — import to ACM:
#   export SECMON_TLS_DOMAIN=secmon.example.com
#   ./scripts/tls/renew_le_import_acm.sh
#
# Renewal: re-run certbot, then this script with ACM_CERTIFICATE_ARN set to existing ARN.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/deploy_common.sh
source "$ROOT/scripts/lib/deploy_common.sh"

DOMAIN="${SECMON_TLS_DOMAIN:-}"
LE_DIR="${SECMON_TLS_LE_DIR:-}"
ACM_ARN="${ACM_CERTIFICATE_ARN:-}"
RUN_CERTBOT=false

usage() {
  cat <<'EOF'
Usage: ./scripts/tls/renew_le_import_acm.sh [options]

Options:
  -d, --domain DOMAIN     Hostname (e.g. secmon.example.com)
  --le-dir PATH           Let's Encrypt live dir (default: /etc/letsencrypt/live/DOMAIN)
  --acm-arn ARN           Re-import into existing ACM certificate (renewal)
  --certbot               Run certbot certonly --manual (interactive DNS-01)
  -h, --help

Environment:
  SECMON_TLS_DOMAIN, SECMON_TLS_LE_DIR, ACM_CERTIFICATE_ARN, AWS_PASS_ENTRY

Example:
  certbot certonly --manual --preferred-challenges dns -d secmon.example.com
  export SECMON_TLS_DOMAIN=secmon.example.com
  ./scripts/tls/renew_le_import_acm.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain) DOMAIN="${2:?}"; shift 2 ;;
    --le-dir) LE_DIR="${2:?}"; shift 2 ;;
    --acm-arn) ACM_ARN="${2:?}"; shift 2 ;;
    --certbot) RUN_CERTBOT=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -n "$DOMAIN" ]] || die "Set SECMON_TLS_DOMAIN or --domain"

LE_DIR="${LE_DIR:-/etc/letsencrypt/live/$DOMAIN}"
FULLCHAIN="$LE_DIR/fullchain.pem"
PRIVKEY="$LE_DIR/privkey.pem"
CHAIN="$LE_DIR/chain.pem"

command -v aws >/dev/null 2>&1 || die "aws CLI required"

export AWS_PASS_ENTRY="${AWS_PASS_ENTRY:-$(deploy_default_pass_entry)}"
deploy_load_aws_from_pass "$AWS_PASS_ENTRY"
deploy_export_aws_region
aws sts get-caller-identity >/dev/null 2>&1 || die "AWS credentials not active"

if [[ "$RUN_CERTBOT" == true ]]; then
  command -v certbot >/dev/null 2>&1 || die "certbot not found"
  echo "=== certbot DNS-01 (interactive) for $DOMAIN ==="
  echo "Add each TXT record your DNS team provides when certbot prompts."
  certbot certonly --manual --preferred-challenges dns -d "$DOMAIN"
fi

[[ -f "$FULLCHAIN" && -f "$PRIVKEY" ]] || die "Missing $FULLCHAIN or $PRIVKEY — run certbot first or set --le-dir"

echo "=== Importing Let's Encrypt cert into ACM ($AWS_REGION) ==="

import_args=(
  --region "$AWS_REGION"
  --certificate "fileb://$FULLCHAIN"
  --private-key "fileb://$PRIVKEY"
)
[[ -f "$CHAIN" ]] && import_args+=(--certificate-chain "fileb://$CHAIN")
[[ -n "$ACM_ARN" ]] && import_args+=(--certificate-arn "$ACM_ARN")

OUT="$(aws acm import-certificate "${import_args[@]}")"
NEW_ARN="$(echo "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("CertificateArn",""))')"
[[ -n "$NEW_ARN" ]] || die "Could not parse CertificateArn"

echo ""
echo "ACM certificate ARN:"
echo "  $NEW_ARN"
echo ""
echo "terraform/envs/aws1590/terraform.tfvars:"
echo "  create_alb_certificate  = false"
echo "  alb_ssl_certificate_arn = \"$NEW_ARN\""
echo ""
echo "  ./terraform/run-with-aws-pass.sh apply"
echo ""
ALB_DNS="$(deploy_tf_output alb_dns_name 2>/dev/null || true)"
echo "DNS team — application CNAME:"
echo "  $DOMAIN -> ${ALB_DNS:-<terraform output alb_dns_name>}"
echo ""
echo "  export STREAMLIT_APP_URL=https://${DOMAIN}/"
echo "  ./scripts/migrate_secrets_to_aws.sh --refresh-ec2"
echo ""
echo "Renewal (~60d): certbot renew && ACM_CERTIFICATE_ARN=$NEW_ARN $0 -d $DOMAIN"
