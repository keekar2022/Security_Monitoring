# Troubleshooting

Common issues and fixes. Replaces HTTP_500_TROUBLESHOOTING and scattered troubleshooting sections.

---

## Authentication & Credentials

| Symptom | Cause | Fix |
|--------|--------|-----|
| HTTP 401 Unauthorized | Invalid or expired token; or token stored with extra lines | Use `echo "TOKEN" \| pass insert -e TrendMicro/ENV/api_token`. Verify: `pass show PATH \| wc -l` = 1. Refresh token if expired. |
| pass not found | Pass not installed or not in PATH | Install: `brew install pass` (macOS) or `apt install pass` (Linux). Or set `USE_PASS=false` and use `config/deployment_config.json`. |
| Password store is empty | Pass not initialized or wrong path | Run `pass init <gpg-id>`. On EC2, use Secrets Manager (`migrate_secrets_to_aws.sh`). |

---

## Configuration

| Symptom | Cause | Fix |
|--------|--------|-----|
| config file not found | Wrong working directory or missing config | Run from project root; ensure `config/deployment_config.json` and `config/environments.json` exist. |
| No environments with credentials | Config has no tokens or Pass entries | Add tokens via Pass or deployment_config; see [CONFIGURATION.md](CONFIGURATION.md#pass--credentials). |

---

## API Errors

| Symptom | Cause | Fix |
|--------|--------|-----|
| HTTP 500 Internal Server Error | Trend Micro API/server-side failure | Your auth is usually OK. Retry later; check status/outages; if beta endpoint, may be unstable. |
| HTTP 403 Forbidden | Token valid but insufficient permissions | Add ASRM / Endpoint Inventory / Risk Insights permissions. See [USER_GUIDE.md](USER_GUIDE.md#endpoint-api-permissions). |

---

## Streamlit dashboard & AEM Gov AU legacy tab

| Symptom | Cause | Fix |
|--------|--------|-----|
| Charts stop before May 8 / 15 | **Years** filter missing **2026** (stale session) | Select **2026** in sidebar, or click **Reload data** |
| May 14 upload “skipped” or no new week | File already processed (SHA-256) or wrong file type | Check **Processed files** ledger; use Splunk `AMSGovCloud_*-2026-05-14.csv` pair |
| Only one “May” point on Trends | Viewing **monthly** charts, not **weekly** | Use **Trends → Weekly snapshots** (top section) |
| Export 7 May not labeled 7 May on chart | Thursday export → **Friday** `scan_date` | 7 May export → **8 May 2026** week (by design) |
| `plotly` import error locally | Missing venv dependency | `pip install -r requirements.txt` or `./scripts/debug/start_dashboard.sh` |
| Stale hero metrics after upload | Cached dataframe | **Reload data** on Legacy tab |

📚 [USER_GUIDE.md](USER_GUIDE.md#aem-gov-au-legacy-tab-v1011)

---

## General

- **Permission denied** on scripts: `chmod +x script.sh`
- **Module not found** (Go): From `go/` run `go mod download` and `go mod tidy`

---

[Back to INDEX](INDEX.md)
