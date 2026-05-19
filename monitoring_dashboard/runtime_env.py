# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Detect Streamlit Community Cloud vs local runtime."""

from __future__ import annotations

import os


def is_streamlit_community_cloud() -> bool:
    """True when the app is served on *.streamlit.app (Community Cloud)."""
    try:
        import streamlit as st
        from streamlit.runtime.scriptrunner_utils.script_run_context import get_script_run_ctx

        if get_script_run_ctx() is None:
            return False
        url = (getattr(st.context, "url", None) or "").strip().lower()
        if "streamlit.app" in url:
            return True
    except Exception:
        pass
    host = (os.environ.get("STREAMLIT_SERVER_ADDRESS") or "").lower()
    return "streamlit.app" in host


def is_ec2_deployment() -> bool:
    """True when collectors run on AWS EC2 (cron + S3), not GitHub Actions."""
    return (os.environ.get("SECMON_COLLECTION_MODE") or "").strip().lower() == "ec2"
