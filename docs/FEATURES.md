# Features: Container & Endpoint Security

Single guide for container vulnerability scanning, endpoint inventory, and endpoint vulnerability scanning. Replaces CONTAINER_SECURITY, ENDPOINT_INVENTORY_GUIDE, ENDPOINT_VULNERABILITIES_README, and ENDPOINT_API_PERMISSIONS.

---

## 1. Container Vulnerability Scanning

**Tool:** `get_container_vulnerabilities` (Go: `./go/bin/get_container_vulnerabilities`)

Discovers Kubernetes clusters in Trend Micro Vision One, fetches vulnerability data, and outputs CSV, TXT, and JSONL.

### Outputs

| File | Purpose |
|------|---------|
| `container_vulnerability_summary.csv` | Excel, DB, pivot tables |
| `container_vulnerability_report.txt` | Human-readable report |
| `container_vulnerability_metrics.jsonl` | Grafana/Loki, time-series |

### Quick start

```bash
# All environments
./go/bin/get_container_vulnerabilities

# One environment
./go/bin/get_container_vulnerabilities --environment production

# Docker
docker compose run --rm --entrypoint /app/get_container_vulnerabilities api --environment production
```

### Options

`--environment`, `--group-name`, `--output`, `--csv-output`, `--otel-output`, `--no-csv`, `--no-otel`, `--quiet`, `--overwrite`. See `--help`.

---

## 2. Endpoint Inventory & Statistics

**Tool:** `get_endpoint_stats` (Go: `./go/bin/get_endpoint_stats`)

Uses OAT (Observed Attack Techniques) detection data for endpoint inventory and security stats. Only endpoints with recent detections are included (not a full asset inventory).

### Outputs

- `endpoint_inventory_summary.csv`
- `endpoint_inventory_report.txt`
- `endpoint_inventory_metrics.jsonl`

### Quick start

```bash
./go/bin/get_endpoint_stats --environment production
docker compose run --rm --entrypoint /app/get_endpoint_stats api --environment production
```

---

## 3. Endpoint/Device Vulnerability Scanning

**Tool:** `get_endpoint_vulnerabilities` (Go: `./go/bin/get_endpoint_vulnerabilities`)

Per-device vulnerability data (CVE, severity, risk score). **Requires extra API permissions**: Attack Surface Risk Management → View, Endpoint Inventory → View, Risk Insights → View (see [ENDPOINT_API_PERMISSIONS](#api-permissions-for-endpoint-vulnerabilities) below).

### Outputs

- `endpoint_vulnerability_summary.csv`
- `endpoint_vulnerability_report.txt`
- `endpoint_vulnerability_metrics.jsonl`

### Quick start

```bash
./go/bin/get_endpoint_vulnerabilities --environment production
docker compose run --rm --entrypoint /app/get_endpoint_vulnerabilities api --environment production
```

---

## 4. Streamlit Dashboard — AEM Gov AU Legacy (v1.0.11)

**App:** `app.py` — **Keekar's Security Monitoring Dashboard**  
**Tab:** **Server Vulnerabilities-Legacy Tool** (weekly M2 / SA / EKS trends, 2022–2026)

### What it does

- Visualizes **AEM Gov AU Vulnerability Scanning Report** weekly aggregates and **Splunk Nexpose** CSV exports.
- **Drag-and-drop multi-file upload** on the Legacy → Upload tab.
- **Weekly** trend charts (each scan week, e.g. 8 May and 15 May 2026) plus **monthly** year-comparison charts.

### Quick start

```bash
./scripts/start_dashboard.sh
# http://localhost:8501/ → Server Vulnerabilities-Legacy Tool
```

### Import data (CLI)

```bash
# Historical AEM spreadsheets (2022–2026)
python3 scripts/import_aem_govau_scan_reports.py ~/Downloads/202*-AEMGovAu-*.csv

# Weekly Splunk Nexpose (M2 + SA for same week)
python3 scripts/import_splunk_scan_reports.py \
  ~/Downloads/AMSGovCloud_M2-Prod-2026-05-14.csv \
  ~/Downloads/AMSGovCloud_Cust_SA_Acct-2026-05-14.csv
```

### Data location

- `data/server_vulnerabilities_legacy/weekly_metrics.jsonl`
- `data/server_vulnerabilities_legacy/meta.json`

📚 **Full reference:** [AEM_GOVAU_LEGACY_DASHBOARD.md](AEM_GOVAU_LEGACY_DASHBOARD.md) · Deploy: [STREAMLIT_CLOUD.md](STREAMLIT_CLOUD.md)

---

## API Permissions for Endpoint Vulnerabilities

If you get permission errors on endpoint/device APIs:

1. In Trend Vision One: **Administration → User Roles**.
2. Edit the role used by your API token.
3. Add: **Attack Surface Risk Management → View**, **Endpoint Inventory → View**, **Risk Insights → View** (and **Device Risk Assessment → View** if available).
4. Regenerate or refresh the API token if required.

---

## Common Options Across Tools

- `--environment` / `-e`: Environment (e.g. production, quality_test).
- `--quiet` / `-q`: Less output (for cron).
- `--overwrite`: Overwrite output files instead of append.
- `--output-dir`: Directory for output files (default: `data`).

Config and credentials: use `config/` and Pass; see [PASS_AND_CREDENTIALS.md](PASS_AND_CREDENTIALS.md) and [CONFIGURATION.md](CONFIGURATION.md).

---

[Back to INDEX](INDEX.md)
