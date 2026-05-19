# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Streamlit UI for scheduled Trend Micro data collection."""

from __future__ import annotations

import os

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
from monitoring_dashboard.runtime_env import is_ec2_deployment, is_streamlit_community_cloud


def render_collection_tab() -> None:
    st.markdown("### Data collection")
    ec2 = is_ec2_deployment()
    bucket = (os.environ.get("METRICS_S3_BUCKET") or "").strip()

    if ec2:
        st.caption(
            "Collectors run on **this EC2 instance** (daily cron). Metrics are stored under "
            f"`s3://{bucket or '<METRICS_S3_BUCKET>'}/data/` and synced locally for the dashboard."
        )
        st.info(
            "AWS deployment: run `/opt/secmon/app/scripts/ec2_daily_collect.sh` via SSM for a manual "
            "collect, or wait for cron (06:00 UTC)."
        )
    elif is_streamlit_community_cloud():
        st.caption("This Streamlit Community Cloud app **displays** metrics only.")
        st.warning(
            "Trend Micro collection is **not** run on Streamlit Cloud. Use "
            "[AWS EC2 deployment](../docs/AWS_DEPLOYMENT.md) (recommended) or collect locally and "
            "upload metrics to S3."
        )
    else:
        st.caption(
            "Local / laptop: run collectors with pass or env tokens; production uses **EC2 cron + S3**."
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
    partial_envs = meta.get("partial_environments") or []
    failed_envs = meta.get("failed_environments") or []
    if partial_envs:
        st.warning(
            "Last run was **partial** (container metrics OK; endpoint ASRM/inventory may need API permissions): "
            + ", ".join(str(e) for e in partial_envs)
        )
    if failed_envs:
        log_hint = "Check `/var/log/secmon/collect.log` on EC2." if ec2 else "Check collector logs on the host that ran collection."
        st.error(
            "Last run **failed** for: "
            + ", ".join(str(e) for e in failed_envs)
            + f". {log_hint}"
        )
    if meta.get("trigger"):
        st.caption(f"Last trigger: {meta.get('trigger')} · duration: {meta.get('duration_seconds', '—')}s")
    elif not last and not ec2:
        st.warning(
            "No successful collection recorded in `data/collection_meta.json`. "
            "Run collection for your deployment mode (see setup below)."
        )

    with st.expander("Schedule & credentials setup"):
        if ec2:
            st.markdown(
                """
1. Populate **Secrets Manager**: `{project}/secmon/app` (Okta, admin) and `{project}/secmon/trendmicro` (API tokens).
2. Publish app release: `./scripts/package_app_release.sh 2.0.0 <s3-bucket>`.
3. Cron runs daily at **06:00 UTC** (`/etc/cron.d/secmon-collect`).
4. Manual collect: `sudo /opt/secmon/app/scripts/ec2_daily_collect.sh`.
5. See [AWS deployment guide](../docs/AWS_DEPLOYMENT.md).
                """.replace("{project}", os.environ.get("SECMON_PROJECT", "ams-secmon"))
            )
        else:
            st.markdown(
                """
1. **AWS production (EC2):** `./scripts/migrate_secrets_to_aws.sh` — see `docs/AWS_DEPLOYMENT.md`.
2. **Local laptop:** `USE_PASS=true ./scripts/run_scheduled_collect.sh` (requires pass or `TRENDMICRO_*_API_TOKEN` env vars).
3. **Upload metrics to S3:** `./scripts/push_local_metrics_to_s3.sh` then `./scripts/aws_deploy.sh --update --metrics-only`.

**Okta / admin login** is separate from Trend Micro API tokens (Secrets Manager on EC2).
                """
            )
        st.text(format_status())
