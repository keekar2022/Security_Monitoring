# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Okta OIDC: discovery, PKCE authorize URL, token exchange (OSCAL-aligned)."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import time
from typing import Any
from urllib.parse import urlencode, urlparse

import httpx
import jwt

from monitoring_dashboard.auth_config import get_effective_client_secret, get_okta_config

OKTA_STATE_TTL_MS = 15 * 60 * 1000


def strip_trailing_slashes(url: str) -> str:
    return (url or "").rstrip("/")


def normalize_domain(domain: str) -> str:
    d = (domain or "").strip().replace("https://", "").replace("http://", "")
    return strip_trailing_slashes(d)


def base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def base64url_decode(data: str) -> bytes:
    padded = data + "=" * ((4 - len(data) % 4) % 4)
    return base64.urlsafe_b64decode(padded)


def generate_code_verifier() -> str:
    return base64url_encode(secrets.token_bytes(32))


def compute_code_challenge(code_verifier: str) -> str:
    digest = hashlib.sha256(code_verifier.encode("utf-8")).digest()
    return base64url_encode(digest)


def state_signing_key(client_secret: str) -> str:
    key = (client_secret or "").strip()
    if key:
        return key
    return (os.environ.get("OKTA_STATE_SIGNING_KEY") or "monitoring-dashboard-oidc-state").strip()


def create_signed_state(redirect_uri: str, client_secret: str, code_verifier: str) -> str:
    payload = {
        "redirectUri": redirect_uri or "",
        "createdAt": int(time.time() * 1000),
        "rnd": secrets.token_hex(8),
        "codeVerifier": code_verifier,
    }
    payload_b64 = base64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    sig_key = state_signing_key(client_secret)
    sig = hmac.new(sig_key.encode("utf-8"), payload_b64.encode("utf-8"), hashlib.sha256).digest()
    return f"{payload_b64}.{base64url_encode(sig)}"


def verify_signed_state(state: str, client_secret: str) -> dict[str, Any] | None:
    if not state or "." not in state:
        return None
    dot = state.index(".")
    payload_b64, sig_b64 = state[:dot], state[dot + 1 :]
    sig_key = state_signing_key(client_secret)
    try:
        expected = hmac.new(sig_key.encode("utf-8"), payload_b64.encode("utf-8"), hashlib.sha256).digest()
        if sig_b64 != base64url_encode(expected):
            return None
        payload = json.loads(base64url_decode(payload_b64).decode("utf-8"))
        created = payload.get("createdAt")
        if not isinstance(created, (int, float)):
            return None
        if int(time.time() * 1000) - int(created) > OKTA_STATE_TTL_MS:
            return None
        return {
            "redirectUri": payload.get("redirectUri") or "",
            "codeVerifier": payload.get("codeVerifier") or "",
        }
    except (json.JSONDecodeError, ValueError, KeyError):
        return None


def _runtime_app_url() -> str:
    """Derive OAuth callback from the browser URL (Streamlit Community Cloud)."""
    try:
        import streamlit as st
        from streamlit.runtime.scriptrunner_utils.script_run_context import get_script_run_ctx

        if get_script_run_ctx() is None:
            return ""
        url = (getattr(st.context, "url", None) or "").strip()
        if not url.startswith("http"):
            return ""
        parsed = urlparse(url)
        if not parsed.scheme or not parsed.netloc:
            return ""
        return f"{parsed.scheme}://{parsed.netloc}/"
    except Exception:
        return ""


def resolve_redirect_uri(explicit: str | None = None) -> str:
    uri = (explicit or "").strip()
    if not uri:
        uri = (os.environ.get("OKTA_REDIRECT_URI") or "").strip()
    if not uri:
        uri = (os.environ.get("STREAMLIT_APP_URL") or "").strip()
    if not uri:
        uri = _runtime_app_url()
    if not uri:
        uri = "http://localhost:8501/"
    if not uri.endswith("/"):
        uri = uri + "/"
    return uri


async def fetch_okta_discovery(domain: str, auth_server_id: str) -> dict[str, Any] | None:
    domain = normalize_domain(domain)
    auth_server_id = (auth_server_id or "").strip()
    if auth_server_id:
        urls = [f"https://{domain}/oauth2/{auth_server_id}/.well-known/openid-configuration"]
    else:
        urls = [
            f"https://{domain}/.well-known/openid-configuration",
            f"https://{domain}/oauth2/default/.well-known/openid-configuration",
        ]
    async with httpx.AsyncClient(timeout=15.0) as client:
        for url in urls:
            try:
                res = await client.get(url)
                if res.status_code == 200:
                    data = res.json()
                    if data.get("authorization_endpoint"):
                        return data
            except httpx.HTTPError:
                continue
    return None


def _ensure_host(url: str, host: str) -> str:
    try:
        parsed = urlparse(url)
        return parsed._replace(netloc=host).geturl()
    except Exception:
        return url


async def build_authorize_url(redirect_uri: str | None = None) -> str:
    okta = get_okta_config()
    domain = normalize_domain(okta.get("domain", ""))
    client_id = (okta.get("clientId") or "").strip()
    client_secret = get_effective_client_secret(okta)
    auth_server_id = (okta.get("authServerId") or "").strip()
    scope = (okta.get("scope") or "openid profile email").strip()
    redirect = resolve_redirect_uri(redirect_uri or okta.get("redirectUri"))

    code_verifier = generate_code_verifier()
    code_challenge = compute_code_challenge(code_verifier)
    state = create_signed_state(redirect, client_secret, code_verifier)

    params = {
        "client_id": client_id,
        "response_type": "code",
        "scope": scope,
        "redirect_uri": redirect,
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
    }
    query = urlencode(params)

    discovery = await fetch_okta_discovery(domain, auth_server_id)
    if discovery and discovery.get("authorization_endpoint"):
        auth_endpoint = _ensure_host(discovery["authorization_endpoint"], domain)
        sep = "&" if "?" in auth_endpoint else "?"
        return f"{auth_endpoint}{sep}{query}"

    oauth2_path = f"oauth2/{auth_server_id}/v1" if auth_server_id else "oauth2/v1"
    return f"https://{domain}/{oauth2_path}/authorize?{query}"


async def exchange_code_for_user(code: str, state: str) -> dict[str, Any]:
    okta = get_okta_config()
    domain = normalize_domain(okta.get("domain", ""))
    client_id = (okta.get("clientId") or "").strip()
    client_secret = get_effective_client_secret(okta)
    auth_server_id = (okta.get("authServerId") or "").strip()

    state_data = verify_signed_state(state, client_secret)
    if not state_data:
        raise ValueError("Invalid or expired state. Please sign in again.")

    redirect_uri = strip_trailing_slashes(state_data.get("redirectUri") or resolve_redirect_uri(okta.get("redirectUri")))
    if not redirect_uri.endswith("/"):
        redirect_uri += "/"
    code_verifier = state_data.get("codeVerifier") or ""

    discovery = await fetch_okta_discovery(domain, auth_server_id)
    if discovery and discovery.get("token_endpoint"):
        token_url = _ensure_host(discovery["token_endpoint"], domain)
        userinfo_url = _ensure_host(discovery.get("userinfo_endpoint", ""), domain) if discovery.get("userinfo_endpoint") else None
    else:
        oauth2_path = f"oauth2/{auth_server_id}/v1" if auth_server_id else "oauth2/v1"
        token_url = f"https://{domain}/{oauth2_path}/token"
        userinfo_url = f"https://{domain}/{oauth2_path}/userinfo"

    async with httpx.AsyncClient(timeout=20.0) as client:
        token_res = await client.post(
            token_url,
            data={
                "grant_type": "authorization_code",
                "client_id": client_id,
                "client_secret": client_secret,
                "code": code,
                "redirect_uri": redirect_uri,
                "code_verifier": code_verifier,
            },
            headers={"Accept": "application/json"},
        )
        if token_res.status_code >= 400:
            err = token_res.json() if token_res.headers.get("content-type", "").startswith("application/json") else {}
            msg = err.get("error_description") or err.get("error") or token_res.text
            raise ValueError(f"Token exchange failed: {msg}")

        tokens = token_res.json()
        access_token = tokens.get("access_token")
        id_token = tokens.get("id_token")
        if not access_token and not id_token:
            raise ValueError("No access token received from Okta.")

        userinfo: dict[str, Any] = {}
        if userinfo_url and access_token:
            ui_res = await client.get(userinfo_url, headers={"Authorization": f"Bearer {access_token}"})
            if ui_res.status_code == 200:
                userinfo = ui_res.json()

        claims: dict[str, Any] = {}
        if id_token:
            try:
                claims = jwt.decode(id_token, options={"verify_signature": False})
            except jwt.PyJWTError:
                claims = {}

        email = userinfo.get("email") or claims.get("email") or claims.get("preferred_username") or ""
        name = userinfo.get("name") or claims.get("name") or email
        sub = userinfo.get("sub") or claims.get("sub") or email

        return {
            "sub": sub,
            "email": email,
            "name": name,
            "access_token": access_token,
            "id_token": id_token,
        }


async def test_okta_connection(okta: dict[str, Any]) -> tuple[bool, str]:
    from monitoring_dashboard.auth_config import MASKED_SECRET

    domain = normalize_domain(okta.get("domain", ""))
    if not domain:
        return False, "Okta domain is required."
    client_id = (okta.get("clientId") or "").strip()
    if not client_id:
        return False, "Client ID is required."
    secret = (okta.get("clientSecret") or "").strip()
    if secret in ("", MASKED_SECRET):
        secret = get_effective_client_secret(okta)
    if not secret:
        return False, "Client secret is required (set in form or OKTA_CLIENT_SECRET)."
    auth_server_id = (okta.get("authServerId") or "").strip()
    discovery = await fetch_okta_discovery(domain, auth_server_id)
    if discovery:
        return True, f"Discovery OK — issuer: {discovery.get('issuer', domain)}"
    return False, "Could not reach Okta OIDC discovery endpoint. Check domain and authorization server ID."
