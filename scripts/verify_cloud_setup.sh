#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Preflight checks for Streamlit Cloud + GitHub Actions deployment.
# Usage: ./scripts/verify_cloud_setup.sh [okta_domain] [auth_server_id]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OKTA_DOMAIN="${1:-${OKTA_DOMAIN:-aemgovau.oktapreview.com}}"
AUTH_SERVER_ID="${2:-${OKTA_AUTH_SERVER_ID:-default}}"
GITHUB_REPO="${GITHUB_REPO:-keekar2022/Security_Monitoring}"
STREAMLIT_URL="${STREAMLIT_APP_URL:-https://aemgovau-secmon.streamlit.app/}"

OKTA_DOMAIN="${OKTA_DOMAIN#https://}"
OKTA_DOMAIN="${OKTA_DOMAIN#http://}"
OKTA_DOMAIN="${OKTA_DOMAIN%%/*}"

pass=0
fail=0

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

echo "=== Okta OIDC discovery ($OKTA_DOMAIN) ==="
if [[ -n "$AUTH_SERVER_ID" ]]; then
  DISCOVERY_URLS=("https://${OKTA_DOMAIN}/oauth2/${AUTH_SERVER_ID}/.well-known/openid-configuration")
else
  DISCOVERY_URLS=(
    "https://${OKTA_DOMAIN}/.well-known/openid-configuration"
    "https://${OKTA_DOMAIN}/oauth2/default/.well-known/openid-configuration"
  )
fi

discovery_ok=false
for url in "${DISCOVERY_URLS[@]}"; do
  code="$(curl -sS -o /tmp/okta-discovery.json -w "%{http_code}" --max-time 15 "$url" || echo "000")"
  if [[ "$code" == "200" ]] && grep -q authorization_endpoint /tmp/okta-discovery.json 2>/dev/null; then
    echo "OK   Discovery: $url"
    discovery_ok=true
    pass=$((pass + 1))
    break
  else
    echo "     $url → HTTP $code"
  fi
done
if [[ "$discovery_ok" != true ]]; then
  echo "FAIL No Okta discovery endpoint reachable (browser *refused to connect* is usually network/firewall)."
  fail=$((fail + 1))
fi

echo ""
echo "=== GitHub Actions workflow ($GITHUB_REPO) ==="
if command -v gh >/dev/null 2>&1; then
  check "gh authenticated" gh auth status
  if gh workflow list -R "$GITHUB_REPO" --json name 2>/dev/null | grep -q "Collect security metrics"; then
    echo "OK   Workflow collect-metrics.yml present"
    pass=$((pass + 1))
  else
    echo "FAIL Workflow collect-metrics.yml not found"
    fail=$((fail + 1))
  fi
  echo "Recent runs:"
  gh run list -R "$GITHUB_REPO" --workflow=collect-metrics.yml --limit 3 2>/dev/null || true
else
  echo "SKIP gh CLI not installed — open https://github.com/${GITHUB_REPO}/actions/workflows/collect-metrics.yml"
fi

echo ""
echo "=== Local repo data ==="
check "deployment_config.json" test -f config/deployment_config.json
if [[ -f data/collection_meta.json ]]; then
  echo "OK   data/collection_meta.json exists"
  pass=$((pass + 1))
else
  echo "WARN data/collection_meta.json missing (normal until first successful GHA run)"
fi

echo ""
echo "=== Reminders ==="
echo "Streamlit app URL: $STREAMLIT_URL"
echo "Okta redirect URI must match exactly (trailing slash): $STREAMLIT_URL"
echo "Set Streamlit Secrets: OKTA_* + optional WORKFLOW_DISPATCH_TOKEN"
echo "Set GitHub secrets: TRENDMICRO_*_API_TOKEN"
echo ""
echo "Result: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
