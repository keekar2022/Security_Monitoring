# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
"""
Trend Micro Vulnerabilities & Inventory Dashboard — Streamlit host with Okta OIDC.

Run locally:
  python3 -m venv .venv && source .venv/bin/activate
  pip install -r requirements.txt
  cp .env.example .env
  streamlit run app.py
"""

from __future__ import annotations

import asyncio
from pathlib import Path

import streamlit as st
from dotenv import load_dotenv

from monitoring_dashboard.auth_config import is_oidc_configured
from monitoring_dashboard.bootstrap_auth import (
    is_settings_authenticated,
    render_bootstrap_login,
    settings_logout,
)
from monitoring_dashboard.okta_oidc import build_authorize_url, exchange_code_for_user
from monitoring_dashboard.secrets_loader import apply_streamlit_secrets
from monitoring_dashboard.ui_dashboard import render_dashboard
from monitoring_dashboard.ui_settings import render_settings_page
from monitoring_dashboard.ui_theme import inject_theme

load_dotenv(Path(__file__).resolve().parent / ".env")

APP_TITLE = "Vulnerabilities & Inventory Dashboard"

st.set_page_config(
    page_title=APP_TITLE,
    layout="wide",
    initial_sidebar_state="expanded",
)
apply_streamlit_secrets()
inject_theme()


def _handle_oauth_callback() -> bool:
    """Process Okta redirect ?code=&state= ; return True if handled."""
    params = st.query_params
    code = params.get("code")
    state = params.get("state")
    if not code or not state:
        return False
    if isinstance(code, list):
        code = code[0]
    if isinstance(state, list):
        state = state[0]
    try:
        user = asyncio.run(exchange_code_for_user(code, state))
        st.session_state.okta_authenticated = True
        st.session_state.okta_user = user
        st.query_params.clear()
        st.rerun()
    except Exception:
        st.error("Sign-in failed. Please try again.")
        if params.get("error"):
            err = params.get("error")
            st.caption(str(err[0] if isinstance(err, list) else err))
        st.query_params.clear()
    return True


def _okta_authenticated() -> bool:
    return bool(st.session_state.get("okta_authenticated") and st.session_state.get("okta_user"))


def _okta_logout() -> None:
    st.session_state.okta_authenticated = False
    st.session_state.okta_user = None


def _render_okta_login() -> None:
    st.markdown(f"## {APP_TITLE}")
    st.caption("Sign in with your organization Okta account to view vulnerability metrics.")
    if st.button("Sign in with Okta", type="primary"):
        try:
            url = asyncio.run(build_authorize_url())
            st.session_state.pending_okta_url = url
        except Exception as exc:
            st.error("Could not start Okta sign-in. Check SSO configuration.")
            st.caption(str(exc))
    url = st.session_state.get("pending_okta_url")
    if url:
        st.link_button("Continue to Okta →", url, type="primary")


def _render_sidebar() -> None:
    with st.sidebar:
        st.markdown("### Navigation")
        if is_oidc_configured() and _okta_authenticated():
            user = st.session_state.get("okta_user") or {}
            st.caption(user.get("email") or user.get("name") or "Signed in")
            if st.button("Sign out (Okta)"):
                _okta_logout()
                st.rerun()
        if st.button("Platform settings (admin)"):
            st.session_state.show_settings = True
            st.rerun()
        if st.session_state.get("show_settings") and st.button("Back to dashboard"):
            st.session_state.show_settings = False
            st.rerun()


def main() -> None:
    if _handle_oauth_callback():
        return

    _render_sidebar()

    if st.session_state.get("show_settings"):
        if not is_settings_authenticated():
            if not render_bootstrap_login():
                return
        render_settings_page(allow_when_configured=True)
        return

    if not is_oidc_configured():
        st.markdown(f"## {APP_TITLE}")
        st.warning("Okta OIDC is not configured. Sign in below to open **Platform Settings**.")
        if not is_settings_authenticated():
            if not render_bootstrap_login():
                return
        render_settings_page()
        return

    if not _okta_authenticated():
        _render_okta_login()
        return

    render_dashboard()
    st.markdown("---")
    st.caption("Trend Micro Vision One metrics · Adobe Managed Services")


main()
