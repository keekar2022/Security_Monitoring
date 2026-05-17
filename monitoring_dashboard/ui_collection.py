# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Streamlit UI for scheduled Trend Micro data collection."""

from __future__ import annotations

import os
from typing import Any

import streamlit as st

from monitoring_dashboard.collection_schedule import (
    format_status,
    get_last_run,
    is_collection_due,
    list_credentialed_environments,
    load_meta,
    load_policy,
    next_due_at,
)

GITHUB_REPO_DEFAULT = "keekar2022/Security_Monitoring"
WORKFLOW_FILE = "collect-metrics.yml"


def _trigger_github_workflow(force: bool = True) -> tuple[bool, str]:
    token = (
        (os.environ.get("WORKFLOW_DISPATCH_TOKEN") or "").strip()
        or (os.environ.get("GITHUB_TOKEN") or "").strip()
    )
    repo = (os.environ.get("GITHUB_REPO") or GITHUB_REPO_DEFAULT).strip()
    ref = (os.environ.get("GITHUB_REF") or "main").strip()
    if not token:
        return False, "Set WORKFLOW_DISPATCH_TOKEN or GITHUB_TOKEN in Streamlit Secrets to trigger runs from the app."

    try:
        import httpx
    except ImportError:
        return False, "httpx is required for workflow dispatch (already in requirements.txt)."

    owner, _, name = repo.partition("/")
    if not owner or not name:
        return False, f"Invalid GITHUB_REPO: {repo}"

    url = f"https://api.github.com/repos/{owner}/{name}/actions/workflows/{WORKFLOW_FILE}/dispatches"
    payload: dict[str, Any] = {"ref": ref, "inputs": {"force": "true" if force else "false"}}

    try:
        with httpx.Client(timeout=30.0) as client:
            res = client.post(
                url,
                json=payload,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28",
                },
            )
        if res.status_code == 204:
            return True, f"Workflow triggered on {repo} ({ref})."
        return False, f"GitHub API {res.status_code}: {res.text[:300]}"
    except httpx.HTTPError as exc:
        return False, f"Request failed: {exc}"


def render_collection_tab() -> None:
    st.markdown("### Data collection")
    st.caption(
        "Collectors run on **GitHub Actions** or **NAS/local cron**, not inside Streamlit Cloud. "
        "Updated JSONL is pushed to `data/` in GitHub; this app reads those files."
    )

    policy = load_policy()
    meta = load_meta()
    last = get_last_run()
    due, reason = is_collection_due()
    freq = str(policy.get("frequency") or "daily")

    c1, c2, c3 = st.columns(3)
    with c1:
        st.metric("Frequency", freq)
    with c2:
        st.metric("Last success", last.strftime("%Y-%m-%d %H:%M UTC") if last else "Never")
    with c3:
        st.metric("Due now", "Yes" if due else "No")

    st.caption(reason)
    if last and not due:
        st.caption(f"Next due (approx.): {next_due_at(last, freq).strftime('%Y-%m-%d %H:%M UTC')}")

    envs = meta.get("environments") or list_credentialed_environments()
    if envs:
        st.markdown("**Environments:** " + ", ".join(envs))
    if meta.get("trigger"):
        st.caption(f"Last trigger: {meta.get('trigger')} · duration: {meta.get('duration_seconds', '—')}s")

    st.markdown("#### Run collection")
    col_a, col_b = st.columns(2)
    with col_a:
        if st.button("Run now (force)", type="primary"):
            ok, msg = _trigger_github_workflow(force=True)
            if ok:
                st.success(msg)
            else:
                st.warning(msg)
    with col_b:
        st.link_button(
            "Open GitHub Actions",
            f"https://github.com/{os.environ.get('GITHUB_REPO', GITHUB_REPO_DEFAULT)}/actions/workflows/{WORKFLOW_FILE}",
        )

    with st.expander("Schedule & credentials setup"):
        st.markdown(
            """
1. **Migrate API keys from pass (local Mac):**
   ```bash
   ./scripts/migrate_pass_to_cloud_credentials.sh
   ```
2. Paste `secrets/generated/streamlit_secrets.fragment.toml` into **Streamlit Cloud → Secrets**.
3. Run `secrets/generated/set_github_secrets.sh` to set GitHub repository secrets.
4. Set `COLLECTION_FREQUENCY` to `daily`, `weekly`, or `monthly` in Streamlit and GitHub secrets.
5. **NAS cron (optional):** `USE_PASS=true ./scripts/run_scheduled_collect.sh` daily (do not enable `PUSH_AFTER_COLLECT` if GitHub Actions pushes).

**Okta / admin login** is separate from Trend Micro API tokens.
            """
        )
        st.text(format_status())
