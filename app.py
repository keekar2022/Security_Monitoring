# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
"""
Keekar's Security Monitoring Dashboard — Trend Micro metrics, Streamlit + Okta OIDC.

Run locally:
  python3 -m venv .venv && source .venv/bin/activate
  pip install -r requirements.txt
  cp .env.example .env
  streamlit run app.py

Deploy (Streamlit Community Cloud): push branch main or Development to
  https://github.com/keekar2022/Security_Monitoring — main file app.py

Docs: docs/USER_GUIDE.md (legacy tab + Splunk upload)
"""

from __future__ import annotations

import html
from pathlib import Path

import streamlit as st
from dotenv import load_dotenv

from monitoring_dashboard.async_utils import run_async
from monitoring_dashboard.auth_config import is_oidc_configured
from monitoring_dashboard.okta_oidc import resolve_redirect_uri
from monitoring_dashboard.bootstrap_auth import (
    is_settings_authenticated,
    render_bootstrap_login,
    settings_logout,
)
from monitoring_dashboard.okta_oidc import (
    OktaConfigError,
    build_authorize_url,
    exchange_code_for_user,
    fetch_okta_discovery_details,
    normalize_domain,
)
from monitoring_dashboard.auth_config import get_okta_config, okta_loaded_from_env
from monitoring_dashboard.runtime_env import is_streamlit_community_cloud
from monitoring_dashboard.secrets_loader import apply_streamlit_secrets
from monitoring_dashboard.app_meta import APP_TITLE
from monitoring_dashboard.ui_dashboard import render_dashboard
from monitoring_dashboard.ui_footer import render_page_footer
from monitoring_dashboard.ui_settings import render_settings_page
from monitoring_dashboard.ui_theme import inject_theme
from monitoring_dashboard.version_info import footer_markdown, get_version_info

load_dotenv(Path(__file__).resolve().parent / ".env")

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
        user = run_async(exchange_code_for_user(code, state))
        st.session_state.okta_authenticated = True
        st.session_state.okta_user = user
        st.session_state.pop("okta_redirect_url", None)
        st.query_params.clear()
        st.rerun()
    except Exception as exc:
        st.error("Sign-in failed. Please try again.")
        st.caption(str(exc))
        if params.get("error"):
            err = params.get("error")
            desc = params.get("error_description")
            st.caption(
                f"Okta: {err[0] if isinstance(err, list) else err}"
                + (
                    f" — {desc[0] if isinstance(desc, list) else desc}"
                    if desc
                    else ""
                )
            )
        st.query_params.clear()
        return False
    return False


def _okta_authenticated() -> bool:
    return bool(st.session_state.get("okta_authenticated") and st.session_state.get("okta_user"))


def _okta_logout() -> None:
    st.session_state.okta_authenticated = False
    st.session_state.okta_user = None


def _render_okta_login() -> None:
    st.title(APP_TITLE)
    st.caption("Sign in with your organization Okta account to view vulnerability metrics.")
    callback = resolve_redirect_uri()
    st.caption(f"Okta callback URL (must match Okta app settings): `{callback}`")

    if is_streamlit_community_cloud():
        if okta_loaded_from_env():
            st.caption("Okta credentials loaded from Streamlit Secrets.")
        else:
            st.warning(
                "On Streamlit Cloud, set **OKTA_*** in **App settings → Secrets** (not only Save in Settings). "
                "Reboot the app after saving. See `docs/AWS_DEPLOYMENT.md` (Streamlit Cloud legacy)."
            )

    redirect_url = st.session_state.get("okta_redirect_url")
    if redirect_url:
        discovery_err = st.session_state.get("okta_discovery_error")
        if discovery_err:
            st.warning("Okta discovery from the app server failed; your browser may still reach Okta.")
            st.markdown(discovery_err)
        st.link_button("Continue to Okta →", redirect_url, type="primary")
        safe_url = html.escape(redirect_url, quote=True)
        st.markdown(
            f'<meta http-equiv="refresh" content="0;url={safe_url}">',
            unsafe_allow_html=True,
        )
        domain = normalize_domain(get_okta_config().get("domain", ""))
        if domain and "oktapreview.com" in domain:
            st.caption(
                f"If the browser shows *refused to connect* for `{domain}`, your network may block Okta Preview. "
                "Test discovery URLs in the expander below or use production Okta in Secrets."
            )
        return

    if st.button("Sign in with Okta", type="primary"):
        try:
            okta = get_okta_config()
            domain = normalize_domain(okta.get("domain", ""))
            auth_server_id = (okta.get("authServerId") or "").strip()
            if domain:
                details = run_async(fetch_okta_discovery_details(domain, auth_server_id))
                if not details.ok:
                    st.session_state["okta_discovery_error"] = details.format_failure_message(
                        domain, auth_server_id
                    )
                else:
                    st.session_state.pop("okta_discovery_error", None)
            st.session_state.okta_redirect_url = run_async(build_authorize_url())
            st.rerun()
        except OktaConfigError as exc:
            st.error(str(exc))
        except Exception as exc:
            st.error("Could not start Okta sign-in. Check SSO configuration.")
            st.caption(str(exc))

    discovery_err = st.session_state.get("okta_discovery_error")
    if discovery_err:
        st.warning("Okta discovery check failed from the app server (sign-in may still work in your browser).")
        st.markdown(discovery_err)

    with st.expander("First-time setup or SSO issues?"):
        okta = get_okta_config()
        domain = normalize_domain(okta.get("domain", ""))
        auth_server_id = (okta.get("authServerId") or "").strip()
        st.markdown(
            "Use **Platform settings (admin)** in the sidebar to configure Okta, "
            "or set secrets in Streamlit Cloud (**App settings → Secrets**). "
            "On Community Cloud, use Secrets (not Save in Settings) for production credentials."
        )
        if domain:
            from monitoring_dashboard.okta_oidc import DiscoveryResult

            st.markdown("**Test these URLs in your browser** (should return JSON):")
            for url in DiscoveryResult().discovery_urls(domain, auth_server_id):
                st.markdown(f"- [{url}]({url})")
        st.markdown(
            """
**Okta Admin (aemgovau-secmon):**

| Field | Value |
|-------|--------|
| Sign-in redirect URI | `https://aemgovau-secmon.streamlit.app/` |
| Sign-out redirect URI | `https://aemgovau-secmon.streamlit.app/` |
| Grant type | Authorization Code |
| PKCE | Required (S256) |
            """
        )


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
    _handle_oauth_callback()

    _render_sidebar()

    if st.session_state.get("show_settings"):
        if not is_settings_authenticated():
            if not render_bootstrap_login():
                return
        render_settings_page(allow_when_configured=True)
        return

    if not is_oidc_configured():
        st.title(APP_TITLE)
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
    render_page_footer(build_line=footer_markdown(get_version_info()))


try:
    main()
except Exception as exc:
    st.error("The dashboard could not start.")
    with st.expander("Error details"):
        st.exception(exc)
