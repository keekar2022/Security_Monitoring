# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Platform Settings — SSO Integration (Okta OIDC), OSCAL-aligned."""

from __future__ import annotations

import streamlit as st

from monitoring_dashboard.async_utils import run_async
from monitoring_dashboard.auth_config import (
    MASKED_SECRET,
    config_for_display,
    config_path,
    is_oidc_configured,
    load_config,
    okta_loaded_from_env,
    save_config,
)
from monitoring_dashboard.bootstrap_auth import is_settings_authenticated, settings_logout
from monitoring_dashboard.okta_oidc import resolve_redirect_uri, test_okta_connection
from monitoring_dashboard.ui_collection import render_collection_tab


def render_settings_page(*, allow_when_configured: bool = False) -> None:
    if not is_settings_authenticated() and not allow_when_configured:
        st.warning("Settings access required.")
        return

    st.markdown("## Platform Settings")
    if is_settings_authenticated():
        col1, col2 = st.columns([4, 1])
        with col2:
            if st.button("Sign out of settings"):
                settings_logout()
                st.rerun()

    tab_sso, tab_collect = st.tabs(["SSO Integration", "Data collection"])
    with tab_sso:
        _render_sso_tab()
    with tab_collect:
        render_collection_tab()


def _render_okta_persistence_help() -> None:
    """Explain where OIDC settings must live so they survive Streamlit reboots."""
    if okta_loaded_from_env():
        st.success(
            "Okta is loaded from **environment / Streamlit Secrets** (`OKTA_*`). "
            "These settings persist across app reboots."
        )
        return
    path = config_path()
    if path.is_file():
        st.info(
            f"Okta is loaded from **`{path.relative_to(path.parent.parent)}`** (saved via this form). "
            "On your laptop this file survives restarts. "
            "On **Streamlit Community Cloud** the disk is wiped on reboot — use **Secrets** instead (see below)."
        )
    else:
        st.warning(
            "Nothing saved yet. **Save configuration** writes `config/auth_config.json` locally. "
            "On **Streamlit Community Cloud**, that file is **lost on every reboot** — "
            "put `OKTA_*` in **App settings → Secrets** (see `docs/STREAMLIT_CLOUD.md`)."
        )


def _render_sso_tab() -> None:
    cfg = config_for_display()
    oauth = cfg.get("oauth", {})
    okta = dict(oauth.get("providers", {}).get("okta", {}))

    st.markdown("### Okta OIDC")
    _render_okta_persistence_help()
    st.caption(
        "Configure **Authorization Code + PKCE** sign-in. "
        "Register the callback URL in Okta exactly as shown below."
    )

    redirect_default = resolve_redirect_uri(okta.get("redirectUri"))
    st.info(f"**Callback URI (Sign-in redirect):** `{redirect_default}`")

    with st.form("sso_config_form"):
        oauth_enabled = st.checkbox("Enable OAuth", value=bool(oauth.get("enabled")))
        okta_enabled = st.checkbox("Enable Okta provider", value=bool(okta.get("enabled")))
        domain = st.text_input("Okta domain", value=okta.get("domain", ""), placeholder="your-org.okta.com")
        auth_server_id = st.text_input(
            "Authorization server ID (optional)",
            value=okta.get("authServerId", ""),
            help='e.g. "default" for custom auth server; leave blank for org server',
        )
        client_id = st.text_input("Client ID", value=okta.get("clientId", ""))
        secret_val = okta.get("clientSecret") or ""
        client_secret = st.text_input(
            "Client secret",
            value="" if secret_val == MASKED_SECRET else secret_val,
            type="password",
            help="Leave blank on save to keep existing secret.",
        )
        redirect_uri = st.text_input("Redirect URI", value=redirect_default)
        scope = st.text_input("Scope", value=okta.get("scope") or "openid profile email")

        col_a, col_b = st.columns(2)
        with col_a:
            test_btn = st.form_submit_button("Test connection")
        with col_b:
            save_btn = st.form_submit_button("Save configuration", type="primary")

    draft = {
        "enabled": oauth_enabled and okta_enabled,
        "domain": domain.strip(),
        "authServerId": auth_server_id.strip(),
        "clientId": client_id.strip(),
        "clientSecret": client_secret.strip() or (MASKED_SECRET if secret_val == MASKED_SECRET else ""),
        "redirectUri": redirect_uri.strip() or redirect_default,
        "scope": scope.strip() or "openid profile email",
    }

    if test_btn:
        ok, msg = run_async(test_okta_connection(draft))
        if ok:
            st.success(msg)
        else:
            st.error("Okta discovery check failed.")
            st.markdown(msg)

    if save_btn:
        if not draft["domain"] or not draft["clientId"]:
            st.error("Domain and Client ID are required.")
            return
        if not draft["clientSecret"] or draft["clientSecret"] == MASKED_SECRET:
            from monitoring_dashboard.auth_config import get_effective_client_secret

            if not get_effective_client_secret(draft):
                st.error("Client secret is required.")
                return

        new_cfg = load_config()
        new_cfg["oauth"]["enabled"] = oauth_enabled and okta_enabled
        new_okta = new_cfg["oauth"]["providers"]["okta"]
        new_okta.update(
            {
                "enabled": okta_enabled,
                "domain": draft["domain"],
                "authServerId": draft["authServerId"],
                "clientId": draft["clientId"],
                "redirectUri": draft["redirectUri"],
                "scope": draft["scope"],
            }
        )
        if client_secret.strip():
            new_okta["clientSecret"] = client_secret.strip()
        elif secret_val == MASKED_SECRET:
            new_okta["clientSecret"] = MASKED_SECRET

        save_config(new_cfg)
        st.success("Configuration saved.")
        if is_oidc_configured():
            st.info("Okta OIDC is configured. Sign out and use **Sign in with Okta** on the main app.")
        st.rerun()

    with st.expander("Okta Admin checklist"):
        st.markdown(
            """
1. **Applications** → Create **OIDC Web Application**
2. **Grant type:** Authorization Code
3. **Callback URI:** use the value shown above (exact match, trailing slash)
4. **Security → API → Authorization Servers** → add **groups** claim if using group mapping later
5. Copy **Client ID** and **Client secret** into this form
            """
        )
