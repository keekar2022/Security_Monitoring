#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Export Trend Micro API tokens from pass into local files for Streamlit Cloud and GitHub Actions.
# Does NOT upload secrets automatically (paste / gh secret set manually).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT_DIR="$ROOT/secrets/generated"
STREAMLIT_OUT="$OUT_DIR/streamlit_secrets.fragment.toml"
GITHUB_OUT="$OUT_DIR/set_github_secrets.sh"
DEPLOYMENT_CONFIG="${DEPLOYMENT_CONFIG:-$ROOT/config/deployment_config.json}"

die() { echo "ERROR: $*" >&2; exit 1; }

if ! command -v pass >/dev/null 2>&1; then
  die "pass is not installed. Install pass or set tokens manually in Streamlit/GitHub secrets."
fi
if ! pass ls >/dev/null 2>&1; then
  die "pass is not initialized."
fi
if [[ ! -f "$DEPLOYMENT_CONFIG" ]]; then
  die "Missing $DEPLOYMENT_CONFIG"
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

mapfile -t ENVIRONMENTS < <(
  python3 - <<'PY' "$DEPLOYMENT_CONFIG"
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
for name in sorted((data.get("environments") or {}).keys()):
    print(name)
PY
)

if [[ ${#ENVIRONMENTS[@]} -eq 0 ]]; then
  die "No environments found in deployment_config.json"
fi

{
  echo "# Concept: Mukesh Kesharwani"
  echo "# Contact: mukesh.kesharwani@adobe.com"
  echo "# Paste into Streamlit Cloud → App settings → Secrets (merge with existing secrets)."
  echo ""
  echo "COLLECTION_FREQUENCY = \"daily\""
  echo ""
} >"$STREAMLIT_OUT"

{
  echo "#!/usr/bin/env bash"
  echo "# Concept: Mukesh Kesharwani"
  echo "# Contact: mukesh.kesharwani@adobe.com"
  echo "# Run each command to set GitHub Actions repository secrets (requires gh auth login)."
  echo "set -euo pipefail"
  echo ""
} >"$GITHUB_OUT"

OK=0
SKIP=0

for env in "${ENVIRONMENTS[@]}"; do
  TOKEN_PATH="TrendMicro/${env}/api_token"
  ENV_KEY="$(echo "$env" | tr '[:lower:]-' '[:upper:]_')"
  SECRET_NAME="TRENDMICRO_${ENV_KEY}_API_TOKEN"

  if ! pass show "$TOKEN_PATH" >/dev/null 2>&1; then
    echo "SKIP: no pass entry for $TOKEN_PATH"
    SKIP=$((SKIP + 1))
    continue
  fi

  TOKEN="$(pass show "$TOKEN_PATH" | head -1 | tr -d '\r\n')"
  LINE_COUNT="$(pass show "$TOKEN_PATH" | wc -l | tr -d ' ')"
  if [[ "$LINE_COUNT" != "1" ]]; then
    echo "WARN: $TOKEN_PATH has $LINE_COUNT lines; using first line only" >&2
  fi
  if [[ -z "$TOKEN" ]]; then
    echo "SKIP: empty token for $env" >&2
    SKIP=$((SKIP + 1))
    continue
  fi

  TOKEN_FILE="$OUT_DIR/${env}.token"
  printf '%s' "$TOKEN" >"$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"

  # Streamlit TOML (escape quotes in token)
  SAFE_TOKEN="${TOKEN//\\/\\\\}"
  SAFE_TOKEN="${SAFE_TOKEN//\"/\\\"}"
  echo "${SECRET_NAME} = \"${SAFE_TOKEN}\"" >>"$STREAMLIT_OUT"
  echo "" >>"$STREAMLIT_OUT"

  # GitHub CLI (run set_github_secrets.sh locally — file is chmod 600, gitignored)
  {
    echo "echo \"Setting ${SECRET_NAME}...\""
    echo "gh secret set \"${SECRET_NAME}\" --repo \"\${GITHUB_REPO:-keekar2022/Security_Monitoring}\" --body-file \"$TOKEN_FILE\""
  } >>"$GITHUB_OUT"
  echo "" >>"$GITHUB_OUT"

  OK=$((OK + 1))
  echo "OK: exported $env → $SECRET_NAME"
done

chmod 600 "$STREAMLIT_OUT" "$GITHUB_OUT"
chmod +x "$GITHUB_OUT"

echo ""
echo "Wrote:"
echo "  $STREAMLIT_OUT"
echo "  $GITHUB_OUT"
echo ""
echo "Next steps:"
echo "  1. Paste streamlit fragment into https://share.streamlit.io/ → your app → Secrets"
echo "  2. Set GitHub secrets: review $GITHUB_OUT and run gh secret set commands"
echo "  3. Set COLLECTION_FREQUENCY in both Streamlit and GitHub (optional repo secret)"
echo "  4. Do NOT commit files under secrets/generated/"
echo ""
echo "Exported: $OK environment(s); skipped: $SKIP"
