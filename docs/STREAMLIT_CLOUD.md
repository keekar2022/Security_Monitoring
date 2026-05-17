---
concept: Mukesh Kesharwani
contact: mukesh.kesharwani@adobe.com
---

# Deploy on Streamlit Community Cloud

Host the vulnerability dashboard at [share.streamlit.io](https://share.streamlit.io/) (same pattern as [Keekar-s-StocksStatus-Dashboard](https://github.com/keekar2022/Keekar-s-StocksStatus-Dashboard)).

## Publish code to GitHub first (required)

Streamlit Community Cloud and `streamlit deploy` only work when **this branch exists on GitHub** with `app.py` committed. If you see:

> The app's code is not connected to a remote GitHub repository

run from the project root:

```bash
chmod +x scripts/publish_streamlit_github.sh
./scripts/publish_streamlit_github.sh
```

That script commits the Streamlit app, dashboard package, sample `data/*_metrics.jsonl`, and pushes to `origin` (default: `keekar2022/Security_Monitoring`).

Manual check:

```bash
git remote -v          # must show github.com
git push origin main   # or your deploy branch
```

## Connect the repository

1. Sign in at [share.streamlit.io](https://share.streamlit.io/) with GitHub (authorize the Streamlit OAuth app).
2. **Create app** → select **keekar2022/Security_Monitoring** (or your fork).
3. **Branch:** `main` (or the branch you pushed).
4. **Main file path:** `app.py`
5. Deploy.

CLI (after push and `streamlit login`):

```bash
source .venv/bin/activate
streamlit deploy app.py
```

## Secrets (App settings → Secrets)

Copy from [`.streamlit/secrets.toml.example`](../.streamlit/secrets.toml.example):

| Secret | Purpose |
|--------|---------|
| `SETTINGS_ADMIN_USER` | Bootstrap login for Settings (default `mkesharw`) |
| `SETTINGS_ADMIN_PASSWORD` | Bootstrap password (change after first login) |
| `OKTA_DOMAIN` | Okta org host, e.g. `your-org.okta.com` |
| `OKTA_CLIENT_ID` | OIDC application client ID |
| `OKTA_CLIENT_SECRET` | OIDC client secret |
| `OKTA_AUTH_SERVER_ID` | Optional, e.g. `default` |
| `OKTA_REDIRECT_URI` | **Required on Cloud** — e.g. `https://aemgovau-secmon.streamlit.app/` |
| `STREAMLIT_APP_URL` | Same as redirect URI (optional if redirect is set) |

## Okta application URLs

For app URL `https://YOUR-APP-NAME.streamlit.app/`:

| Okta field | Value |
|------------|--------|
| **Sign-in redirect URI** | `https://YOUR-APP-NAME.streamlit.app/` |
| **Sign-out redirect URI** | `https://YOUR-APP-NAME.streamlit.app/` |
| **Grant type** | Authorization Code |
| **PKCE** | Required (app sends S256 challenge) |

Until Okta is configured, the app shows the **Settings** page after bootstrap login (`SETTINGS_ADMIN_*`).

After OIDC is saved, users **Sign in with Okta** to reach the dashboard.

## Local development

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
streamlit run app.py
```

Okta callback for local: `http://localhost:8501/`
