# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Bootstrap login for Settings page before Okta OIDC is configured."""

from __future__ import annotations

import os
import time

import bcrypt
import streamlit as st

# Bcrypt hash for default password TryMein2026 (rounds=12). Override via SETTINGS_ADMIN_PASSWORD env.
_DEFAULT_PASSWORD_HASH = (
    "$2b$12$7MKGCdlcZ1tdVCkrPPbxhefv2JUiIqsXVgk/24xdabbCpaIAjPegy"
)
_MAX_ATTEMPTS = 5
_LOCKOUT_SECONDS = 60
_DEFAULT_PASSWORD = "TryMein2026"
_PASSWORD_PLACEHOLDERS = frozenset(
    {"", "change-me", "change-me-after-first-login", "your-password", "your_password"}
)


def _admin_user() -> str:
    return (os.environ.get("SETTINGS_ADMIN_USER") or "mkesharw").strip()


def _configured_admin_password() -> str:
    """Return explicit admin password from env, or empty if unset / placeholder."""
    value = (os.environ.get("SETTINGS_ADMIN_PASSWORD") or "").strip()
    if value.lower() in _PASSWORD_PLACEHOLDERS:
        return ""
    return value


def _using_cloud_password_override() -> bool:
    return bool(_configured_admin_password())


def _verify_password(password: str) -> bool:
    env_password = _configured_admin_password()
    if env_password:
        return password == env_password
    env_hash = (os.environ.get("SETTINGS_ADMIN_PASSWORD_BCRYPT") or "").strip()
    hash_val = env_hash or _DEFAULT_PASSWORD_HASH
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hash_val.encode("utf-8"))
    except ValueError:
        return False


def is_settings_authenticated() -> bool:
    return bool(st.session_state.get("settings_authenticated"))


def settings_logout() -> None:
    st.session_state.settings_authenticated = False


def render_bootstrap_login() -> bool:
    """
    Render login form. Returns True if authenticated after submit.
    """
    if is_settings_authenticated():
        return True

    attempts = st.session_state.get("bootstrap_attempts", 0)
    locked_until = st.session_state.get("bootstrap_locked_until", 0)
    now = time.time()
    if locked_until and now < locked_until:
        st.error(f"Too many attempts. Try again in {int(locked_until - now)} seconds.")
        return False

    st.subheader("Settings access")
    st.caption("Sign in to configure Okta OIDC. Okta is not configured yet.")
    if _using_cloud_password_override():
        st.caption(
            f"Username: **{_admin_user()}** · Password is the value of "
            "`SETTINGS_ADMIN_PASSWORD` in Streamlit Cloud **Secrets** (not the code default)."
        )
    else:
        st.caption(
            f"Username: **{_admin_user()}** · Default password: **`{_DEFAULT_PASSWORD}`** "
            "(capital **M**). Override via `SETTINGS_ADMIN_PASSWORD` in Secrets or `.env`."
        )

    with st.form("bootstrap_login"):
        username = st.text_input("Username", autocomplete="username")
        password = st.text_input("Password", type="password", autocomplete="current-password")
        submitted = st.form_submit_button("Sign in", type="primary")

    if not submitted:
        return False

    if username.strip() != _admin_user():
        st.error("Invalid username or password.")
        _record_failed_attempt()
        return False

    if not _verify_password(password):
        st.error("Invalid username or password.")
        _record_failed_attempt()
        return False

    st.session_state.settings_authenticated = True
    st.session_state.bootstrap_attempts = 0
    st.session_state.bootstrap_locked_until = 0
    st.rerun()
    return True


def _record_failed_attempt() -> None:
    attempts = st.session_state.get("bootstrap_attempts", 0) + 1
    st.session_state.bootstrap_attempts = attempts
    if attempts >= _MAX_ATTEMPTS:
        st.session_state.bootstrap_locked_until = time.time() + _LOCKOUT_SECONDS
        st.session_state.bootstrap_attempts = 0
