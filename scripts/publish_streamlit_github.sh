#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Publish Streamlit dashboard files to GitHub so Community Cloud / `streamlit deploy` can connect.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die() { echo "ERROR: $*" >&2; exit 1; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "Not a git repository. Run from the project root."
fi

REMOTE="${STREAMLIT_GIT_REMOTE:-origin}"
BRANCH="${STREAMLIT_GIT_BRANCH:-$(git branch --show-current)}"

URL="$(git remote get-url "$REMOTE" 2>/dev/null || true)"
case "$URL" in
  *github.com*) ;;
  *)
    die "Remote '$REMOTE' is not GitHub ($URL). Set STREAMLIT_GIT_REMOTE or add: git remote add origin https://github.com/USER/REPO.git"
    ;;
esac

echo "Repository: $URL"
echo "Branch:     $BRANCH"
echo ""

FILES=(
  app.py
  requirements.txt
  monitoring_dashboard
  .streamlit/config.toml
  .streamlit/secrets.toml.example
  .env.example
  config/auth_config.json.example
  docs/STREAMLIT_CLOUD.md
  scripts/start_dashboard.sh
  scripts/publish_streamlit_github.sh
  data/container_vulnerability_metrics.jsonl
  data/endpoint_inventory_metrics.jsonl
  data/endpoint_vulnerability_metrics.jsonl
)

git add "${FILES[@]}" .gitignore

if git diff --cached --quiet; then
  echo "Nothing new to commit (Streamlit files already staged/committed)."
else
  git commit -m "$(cat <<EOF
feat: add Streamlit vulnerability dashboard for Community Cloud

Publish app.py, monitoring_dashboard package, and sample JSONL metrics so
share.streamlit.io and streamlit deploy can link this branch on GitHub.
EOF
)"
fi

REPO_SLUG="$(echo "$URL" | sed -E 's#.*github.com[:/](.+)(\.git)?#\1#')"

echo "Pushing $BRANCH to $REMOTE..."
git push "$REMOTE" "$BRANCH"

# Streamlit / dual-repo workflows often use Development; keep it in sync with main.
if [[ "$BRANCH" == "main" ]]; then
  echo "Updating remote Development branch (same commit as main)..."
  git push "$REMOTE" "HEAD:Development"
fi

if command -v gh >/dev/null 2>&1; then
  if gh api "repos/$REPO_SLUG/contents/app.py?ref=$BRANCH" --jq .sha >/dev/null 2>&1; then
    echo "Verified: app.py is on GitHub ($REPO_SLUG, branch $BRANCH)."
  else
    die "app.py not found on GitHub after push. Check repo access and branch name."
  fi
fi

echo ""
echo "Done. Next:"
echo "  1. Open https://share.streamlit.io/ → Create app"
echo "  2. Repo: $REPO_SLUG"
echo "  3. Branch: main or Development   Main file: app.py"
echo "  4. Or run: streamlit deploy   (from this directory, after GitHub login)"
echo "  5. Set Secrets from .streamlit/secrets.toml.example"
