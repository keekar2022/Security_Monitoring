---
concept: Mukesh Kesharwani
contact: mukesh.kesharwani@adobe.com
---

# User Guide — Security Monitoring Dashboard

Get started with the **Streamlit dashboard**, **Go collectors**, and the **AEM Gov AU legacy** tab. Production hosting is on **AWS** — see [AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md).

---

## Dashboard (local)

```bash
./scripts/debug/start_dashboard.sh
# Open http://localhost:8501/
```

Or: `python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && streamlit run app.py`

| Task | How |
|------|-----|
| Trend Micro tabs | JSONL under `data/*_metrics.jsonl` (from EC2 collect or local collect) |
| Legacy weekly trends | Tab **Server Vulnerabilities-Legacy Tool** |
| Upload Splunk/AEM CSVs | Legacy → **Upload** (multi-file) |
| Production deploy | [AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md) |

---

## Go collectors (Trend Micro)

Build once:

```bash
cd go && make collector   # or: make tools
```

Run one environment:

```bash
./go/bin/get_container_vulnerabilities --environment production
./go/bin/get_endpoint_stats --environment production
./go/bin/get_endpoint_vulnerabilities --environment production
```

Scheduled collect (laptop, pass or env tokens):

```bash
USE_PASS=true ./scripts/run_scheduled_collect.sh
```

Production uses `./scripts/run_scheduled_collect.sh --ec2` on EC2 (Secrets Manager tokens). See [AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md).

### Outputs

| Tool | JSONL | Notes |
|------|-------|--------|
| `get_container_vulnerabilities` | `container_vulnerability_metrics.jsonl` | Cluster-level vulns |
| `get_endpoint_stats` | `endpoint_inventory_metrics.jsonl` | OAT-based inventory |
| `get_endpoint_vulnerabilities` | `endpoint_vulnerability_metrics.jsonl` | Needs ASRM permissions |

Common flags: `--environment`, `--quiet`, `--overwrite`, `--output-dir`. Run `--help` on each binary.

### Endpoint API permissions

If endpoint/device APIs return permission errors, add in Trend Vision One → **Administration → User Roles**: **Attack Surface Risk Management → View**, **Endpoint Inventory → View**, **Risk Insights → View**.

---

## AEM Gov AU legacy tab (v1.0.11+)

**Tab:** **Server Vulnerabilities-Legacy Tool** — weekly M2 / SA / EKS trends (2022–2026) from AEM spreadsheets and Splunk Nexpose exports.

### Data store

| Path | Purpose |
|------|---------|
| `data/server_vulnerabilities_legacy/weekly_metrics.jsonl` | One JSON object per scan week |
| `data/server_vulnerabilities_legacy/meta.json` | Schema version, cutoff dates |
| `data/server_vulnerabilities_legacy/processed_uploads.json` | Upload deduplication (SHA-256) |

### Upload (UI)

1. Open **Server Vulnerabilities-Legacy Tool** → **Upload**.
2. Drag and drop CSV files → **Process upload** → **Reload data**.

| Type | Filename pattern |
|------|------------------|
| AEM weekly report | `*-AEMGovAu-Vulnerability-Scanning-Report.csv` |
| Splunk M2 | `AMSGovCloud_M2-Prod-YYYY-MM-DD.csv` |
| Splunk SA | `AMSGovCloud_Cust_SA_Acct-YYYY-MM-DD.csv` |

Splunk exports (usually Thursday) are stored under the **following Friday** `scan_date`. Include **2026** in the **Years** filter for recent weeks.

### CLI import

```bash
python3 scripts/debug/import_aem_govau_scan_reports.py \
  ~/Downloads/202*-AEMGovAu-Vulnerability-Scanning-Report.csv

python3 scripts/debug/import_splunk_scan_reports.py \
  ~/Downloads/AMSGovCloud_M2-Prod-2026-05-14.csv \
  ~/Downloads/AMSGovCloud_Cust_SA_Acct-2026-05-14.csv
```

Use `--dry-run` on Splunk import to parse without writing.

### Charts

| Tab | Content |
|-----|---------|
| **Overview** | Last 20 weeks TTV; full-history with range slider |
| **Trends** | Weekly snapshots (one point per scan week) |
| **Trends** | Monthly comparison (averaged by month/year) |
| **By environment** | M2 vs SA per-server |
| **Data** | Full weekly table |

### Deploy legacy data

Commit `data/server_vulnerabilities_legacy/` and run `./scripts/package_app_release.sh` + instance refresh, or push via git if using Streamlit Cloud (legacy — see [AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md#streamlit-community-cloud-legacy)).

Trend Micro JSONL is updated by **EC2 cron** or local collect + S3; legacy data is updated by **import or UI upload** only.

---

## Related docs

| Doc | Topic |
|-----|--------|
| [CONFIGURATION.md](CONFIGURATION.md) | Config files, pass, APIs, monitoring |
| [AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md) | EC2, Terraform, Secrets Manager |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common fixes |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

[Back to INDEX](INDEX.md)
