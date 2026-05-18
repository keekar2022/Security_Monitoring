# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Load and persist OIDC / Okta configuration."""

from __future__ import annotations

import json
import os
from copy import deepcopy
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG_PATH = ROOT / "config" / "auth_config.json"
MASKED_SECRET = "••••••••"

_PLACEHOLDER_VALUES = frozenset(
    {
        "",
        "your-org.okta.com",
        "your_client_id",
        "your_client_secret",
        "change-me",
        "change-me-after-first-login",
    }
)


def _is_placeholder(value: str) -> bool:
    return (value or "").strip().lower() in _PLACEHOLDER_VALUES


def config_path() -> Path:
    return Path(os.environ.get("AUTH_CONFIG_PATH", str(DEFAULT_CONFIG_PATH)))


def _default_config() -> dict[str, Any]:
    return {
        "oauth": {
            "enabled": False,
            "providers": {
                "okta": {
                    "enabled": False,
                    "domain": "",
                    "authServerId": "",
                    "clientId": "",
                    "clientSecret": "",
                    "redirectUri": "",
                    "scope": "openid profile email",
                }
            },
        }
    }


def _merge_env_into_okta(okta: dict[str, Any]) -> dict[str, Any]:
    """Streamlit Cloud secrets override file config."""
    out = dict(okta)
    env_map = {
        "domain": "OKTA_DOMAIN",
        "clientId": "OKTA_CLIENT_ID",
        "clientSecret": "OKTA_CLIENT_SECRET",
        "authServerId": "OKTA_AUTH_SERVER_ID",
        "scope": "OKTA_SCOPE",
        "redirectUri": "OKTA_REDIRECT_URI",
    }
    for field, env_key in env_map.items():
        val = (os.environ.get(env_key) or "").strip()
        if val and not _is_placeholder(val):
            out[field] = val
    client_id = (os.environ.get("OKTA_CLIENT_ID") or "").strip()
    if client_id and not _is_placeholder(client_id):
        out["enabled"] = True
    return out


def load_config() -> dict[str, Any]:
    cfg = _default_config()
    path = config_path()
    if path.is_file():
        try:
            with path.open(encoding="utf-8") as f:
                disk = json.load(f)
            if isinstance(disk, dict):
                oauth = disk.get("oauth")
                if isinstance(oauth, dict):
                    cfg["oauth"].update({k: v for k, v in oauth.items() if k != "providers"})
                    providers = oauth.get("providers")
                    if isinstance(providers, dict) and isinstance(providers.get("okta"), dict):
                        cfg["oauth"]["providers"]["okta"].update(providers["okta"])
        except (json.JSONDecodeError, OSError):
            pass

    okta = cfg["oauth"]["providers"]["okta"]
    cfg["oauth"]["providers"]["okta"] = _merge_env_into_okta(okta)

    if cfg["oauth"]["providers"]["okta"].get("enabled") and cfg["oauth"]["providers"]["okta"].get("clientId"):
        cfg["oauth"]["enabled"] = True

    return cfg


def save_config(cfg: dict[str, Any]) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    to_write = deepcopy(cfg)
    okta = to_write.get("oauth", {}).get("providers", {}).get("okta", {})
    secret = (okta.get("clientSecret") or "").strip()
    if secret == MASKED_SECRET:
        existing = load_config()
        prev = existing.get("oauth", {}).get("providers", {}).get("okta", {}).get("clientSecret", "")
        if prev and prev != MASKED_SECRET:
            okta["clientSecret"] = prev
    with path.open("w", encoding="utf-8") as f:
        json.dump(to_write, f, indent=2)
        f.write("\n")


def get_okta_config() -> dict[str, Any]:
    return load_config().get("oauth", {}).get("providers", {}).get("okta", {})


def get_effective_client_secret(okta: dict[str, Any] | None = None) -> str:
    okta = okta or get_okta_config()
    secret = (okta.get("clientSecret") or "").strip()
    if secret and secret != MASKED_SECRET:
        return secret
    return (os.environ.get("OKTA_CLIENT_SECRET") or "").strip()


def is_oidc_configured() -> bool:
    cfg = load_config()
    oauth = cfg.get("oauth", {})
    okta = oauth.get("providers", {}).get("okta", {})
    if not oauth.get("enabled") or not okta.get("enabled"):
        return False
    domain = (okta.get("domain") or "").strip()
    client_id = (okta.get("clientId") or "").strip()
    secret = get_effective_client_secret(okta)
    if _is_placeholder(domain) or _is_placeholder(client_id) or _is_placeholder(secret):
        return False
    return bool(domain and client_id and secret)


def okta_loaded_from_env() -> bool:
    """True when OKTA_* env vars (or Streamlit Secrets) supply the OIDC client."""
    domain = (os.environ.get("OKTA_DOMAIN") or "").strip()
    client_id = (os.environ.get("OKTA_CLIENT_ID") or "").strip()
    secret = (os.environ.get("OKTA_CLIENT_SECRET") or "").strip()
    if _is_placeholder(domain) or _is_placeholder(client_id) or _is_placeholder(secret):
        return False
    return bool(domain and client_id and secret)


def config_for_display() -> dict[str, Any]:
    """Return config safe for UI (masked secret)."""
    cfg = load_config()
    okta = cfg.get("oauth", {}).get("providers", {}).get("okta", {})
    if okta.get("clientSecret"):
        okta = {**okta, "clientSecret": MASKED_SECRET}
    cfg["oauth"]["providers"]["okta"] = okta
    return cfg
