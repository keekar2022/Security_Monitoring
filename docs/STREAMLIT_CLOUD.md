---
concept: Mukesh Kesharwani
contact: mukesh.kesharwani@adobe.com
---

# Deploy on Streamlit Community Cloud

Host **Keekar's Security Monitoring Dashboard** (release **1.0.11**, see [`VERSION`](../VERSION)) at [share.streamlit.io](https://share.streamlit.io/) (same pattern as [Keekar-s-StocksStatus-Dashboard](https://github.com/keekar2022/Keekar-s-StocksStatus-Dashboard)).

**Tabs:** Trend Micro container/endpoint metrics (JSONL from GitHub Actions) and **ServerVulnerabilities-LegacyTool** (AEM Gov AU weekly + Splunk Nexpose — see [AEM_GOVAU_LEGACY_DASHBOARD.md](AEM_GOVAU_LEGACY_DASHBOARD.md)).

## Publish code to GitHub first (required)

Streamlit Community Cloud and `streamlit deploy` only work when **this branch exists on GitHub** with `app.py` committed. If you see:

> The app's code is not connected to a remote GitHub repository

run from the project root:

```bash
chmod +x scripts/publish_streamlit_github.sh
./scripts/publish_streamlit_github.sh
```

That script commits the Streamlit app, dashboard package, sample `data/*_metrics.jsonl`, **`data/server_vulnerabilities_legacy/`** (weekly AEM/Splunk metrics), and pushes to `origin` (default: `keekar2022/Security_Monitoring`).

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

## Okta OIDC persistence (important)

**Why settings disappear after reboot:** The Settings UI saves Okta to `config/auth_config.json` on the container disk. Streamlit Community Cloud uses an **ephemeral filesystem** — that file is **deleted on every app restart or redeploy**.

**What to do:** Store Okta in **App settings → Secrets** (not only via the Settings form). The app reads `OKTA_*` from Secrets on every startup (`monitoring_dashboard/secrets_loader.py`).

1. Open your app on [share.streamlit.io](https://share.streamlit.io/) → **Manage app** → **Settings** → **Secrets**.
2. Paste (replace placeholders) — match [`.streamlit/secrets.toml.example`](../.streamlit/secrets.toml.example):

```toml
OKTA_DOMAIN = "your-org.okta.com"
OKTA_CLIENT_ID = "your_client_id"
OKTA_CLIENT_SECRET = "your_client_secret"
OKTA_AUTH_SERVER_ID = "default"
OKTA_SCOPE = "openid profile email"
OKTA_REDIRECT_URI = "https://YOUR-APP-NAME.streamlit.app/"
STREAMLIT_APP_URL = "https://YOUR-APP-NAME.streamlit.app/"
```

3. **Save** Secrets and **Reboot** the app. In **Platform settings → SSO Integration**, you should see a green banner: *loaded from environment / Streamlit Secrets*.

4. Register the same **callback URL** in your Okta OIDC app (trailing slash must match).

**Local laptop (not Cloud):** Either keep using **Save configuration** (`config/auth_config.json`, gitignored), or copy secrets to `.streamlit/secrets.toml` (also gitignored) for the same persistence model.

---

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

## Scheduled data collection

Streamlit Cloud **does not** run Trend Micro collectors. Collection runs via **GitHub Actions** (primary) and optional **NAS/Mac cron**, then pushes updated `data/*.jsonl` to GitHub for this app to display.

### 1. Migrate API keys from local pass

On a machine with `pass` and your Trend Micro tokens:

```bash
chmod +x scripts/migrate_pass_to_cloud_credentials.sh
./scripts/migrate_pass_to_cloud_credentials.sh
```

This writes (gitignored, mode `600`):

- `secrets/generated/streamlit_secrets.fragment.toml` → paste into **Streamlit Cloud → Secrets**
- `secrets/generated/set_github_secrets.sh` → run locally to set GitHub repository secrets
- `secrets/generated/<env>.token` → used by the GitHub secret script

### 2. GitHub Actions secrets

Set repository secrets on `keekar2022/Security_Monitoring` (names must match):

| Secret | Purpose |
|--------|---------|
| `TRENDMICRO_PRODUCTION_API_TOKEN` | Trend Micro API token |
| `TRENDMICRO_PRODUCTION_AU_API_TOKEN` | AU production token |
| `TRENDMICRO_QUALITY_TEST_API_TOKEN` | QTE token |
| `TRENDMICRO_AMS_QTE_API_TOKEN` | AMS QTE token |
| `COLLECTION_FREQUENCY` | Optional override: `daily`, `weekly`, or `monthly` |

Enable workflow [`.github/workflows/collect-metrics.yml`](../.github/workflows/collect-metrics.yml) (runs daily 06:00 UTC; skips if not due).

Manual run: **Actions → Collect security metrics → Run workflow** (use `force=true` to ignore schedule).

### 3. Schedule policy

Default: [`config/collection_schedule.json`](../config/collection_schedule.json) (`frequency`: daily).

| Frequency | Runs when |
|-----------|-----------|
| `daily` | ≥ 1 day since last success |
| `weekly` | ≥ 7 days |
| `monthly` | ≥ 30 days |

Override without git commit: set `COLLECTION_FREQUENCY` in Streamlit Secrets and GitHub secret `COLLECTION_FREQUENCY`.

### 4. Streamlit Settings → Data collection

After bootstrap/Okta login → **Platform settings** → **Data collection** tab:

- Last run, next due, environments
- **Run now (force)** — triggers GitHub Actions if `WORKFLOW_DISPATCH_TOKEN` is set
- Setup instructions

### 5. NAS / Mac cron (optional backup)

```bash
0 7 * * * cd /path/to/Monitoring-API-Dev && USE_PASS=true ./scripts/run_scheduled_collect.sh >> logs/collect.log 2>&1
```

Use **either** GitHub Actions **or** `PUSH_AFTER_COLLECT=true` on NAS — not both pushing to the same branch.

## AEM Gov AU legacy weekly data (v1.0.11+)

Trend Micro collectors **do not** populate `data/server_vulnerabilities_legacy/`. Update that store by:

1. **UI:** Legacy tab → Upload → drag AEM or Splunk CSVs → **Process upload** → **Reload data**.
2. **CLI:** `scripts/import_aem_govau_scan_reports.py` and/or `scripts/import_splunk_scan_reports.py`.
3. Commit and push `data/server_vulnerabilities_legacy/` before or with `./scripts/publish_streamlit_github.sh`.

Splunk export dates (Thursday) appear on charts as the **following Friday** scan week. Include **2026** in the sidebar **Years** filter to see recent May weeks.

📚 [AEM_GOVAU_LEGACY_DASHBOARD.md](AEM_GOVAU_LEGACY_DASHBOARD.md) · [CHANGELOG.md](CHANGELOG.md#1011--2026-05-18--aem-gov-au-legacy-dashboard--splunk-ingest)
