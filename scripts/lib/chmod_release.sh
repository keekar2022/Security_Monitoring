#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Ensure shell scripts and Go binaries are executable (S3 sync does not preserve mode).

secmon_chmod_release_tree() {
  local root="${1:?app root path}"
  [[ -d "$root" ]] || return 0

  if [[ -d "$root/scripts" ]]; then
    find "$root/scripts" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  fi
  if [[ -d "$root/go/bin" ]]; then
    find "$root/go/bin" -type f -exec chmod +x {} + 2>/dev/null || true
  fi
  for f in "$root/scripts/ec2_daily_collect.sh" "$root/scripts/ec2_fetch_secrets.sh" \
    "$root/scripts/run_scheduled_collect.sh" "$root/scripts/ec2_repair_streamlit_remote.sh"; do
    [[ -f "$f" ]] && chmod +x "$f" 2>/dev/null || true
  done
}
