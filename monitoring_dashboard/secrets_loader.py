# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Load Streamlit Cloud secrets into os.environ (``.env`` is used for local dev)."""

from __future__ import annotations

import os

_SECRET_KEYS = (
    "SETTINGS_ADMIN_USER",
    "SETTINGS_ADMIN_PASSWORD",
    "SETTINGS_ADMIN_PASSWORD_BCRYPT",
    "OKTA_DOMAIN",
    "OKTA_CLIENT_ID",
    "OKTA_CLIENT_SECRET",
    "OKTA_AUTH_SERVER_ID",
    "OKTA_SCOPE",
    "OKTA_REDIRECT_URI",
    "OKTA_STATE_SIGNING_KEY",
    "DATA_DIR",
    "STREAMLIT_APP_URL",
)


def _set_from_mapping(mapping: object) -> None:
    if not hasattr(mapping, "items"):
        return
    for key, value in mapping.items():
        if key in _SECRET_KEYS and value is not None:
            text = str(value).strip()
            if text and not (os.environ.get(key) or "").strip():
                os.environ[key] = text


def apply_streamlit_secrets() -> None:
    """Copy ``st.secrets`` into ``os.environ`` when not already set."""
    try:
        import streamlit as st
        from streamlit.errors import StreamlitSecretNotFoundError
    except ImportError:
        return

    try:
        _set_from_mapping(st.secrets)
        if hasattr(st.secrets, "get"):
            env_section = st.secrets.get("env")
            if env_section is not None:
                _set_from_mapping(env_section)
    except StreamlitSecretNotFoundError:
        return
    except (AttributeError, TypeError, KeyError):
        return
