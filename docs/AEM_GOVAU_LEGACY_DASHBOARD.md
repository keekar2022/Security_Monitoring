---
concept: Mukesh Kesharwani
contact: mukesh.kesharwani@adobe.com
---

# AEM Gov AU Legacy Vulnerability Dashboard

**Release:** 1.0.11 (see root [`VERSION`](../VERSION))  
**App title:** Keekar's Security Monitoring Dashboard  
**Tab:** **ServerVulnerabilities-LegacyTool** (first tab in the Streamlit app)

Weekly vulnerability trends for **AMSGovCloud M2-Prod**, **Cust SA Acct**, and **EKS_AEMGovAU_PROD_Cluster** (2022–2026), sourced from AEM Gov AU scanning spreadsheets and Splunk Nexpose exports.

---

## Data store

| Path | Purpose |
|------|---------|
| `data/server_vulnerabilities_legacy/weekly_metrics.jsonl` | One JSON object per scan week |
| `data/server_vulnerabilities_legacy/meta.json` | Schema version, last data date, projected-data cutoff |
| `data/server_vulnerabilities_legacy/processed_uploads.json` | Upload ledger (SHA-256 deduplication) |

**Schema v2** fields include: `scan_date`, `m2_servers`, `m2_ttv`, `sa_servers`, `sa_ttv`, `container_vul_count`, `m2_per_server`, `sa_per_server`, optional `splunk_sources` and severity breakdowns.

---

## Run the dashboard locally

```bash
./scripts/start_dashboard.sh
# Open http://localhost:8501/
```

Or:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
streamlit run app.py
```

After code or data changes, use **Reload data** on the Legacy tab (or restart Streamlit).

---

## Uploading scan data (UI)

1. Open **ServerVulnerabilities-LegacyTool** → **Upload**.
2. **Drag and drop** one or more CSV files (or click to browse).
3. Click **Process upload**.

### Supported file types

| Type | Filename pattern | Effect |
|------|------------------|--------|
| **AEM Gov AU weekly report** | `*-AEMGovAu-Vulnerability-Scanning-Report.csv` | Merges weekly rows (M2/SA/Containers) |
| **Splunk Nexpose M2** | `AMSGovCloud_M2-Prod-YYYY-MM-DD.csv` | Updates M2 servers + TTV for that week |
| **Splunk Nexpose SA** | `AMSGovCloud_Cust_SA_Acct-YYYY-MM-DD.csv` | Updates SA servers + TTV for that week |

Splunk uploads **preserve** existing container/EKS fields on the same week when AEM data already exists.

### Scan week vs export date

Splunk exports are usually pulled on **Thursday**. The dashboard stores them under the **following Friday** (`scan_date`), matching AEM weekly reports.

| Export file date (Thu) | Dashboard `scan_date` (Fri) |
|------------------------|-----------------------------|
| 2026-05-07 | 2026-05-08 |
| 2026-05-14 | 2026-05-15 |

Hover charts for exact dates (e.g. **08 May 2026**, **15 May 2026**).

### Projected / forward-filled AEM rows

Bulk import from historical AEM spreadsheets excludes rows on or after **`2026-05-13`** (configurable via `AEM_PREDICTED_CUTOFF`). **Manual uploads and Splunk exports are not blocked** by this cutoff—only bulk spreadsheet import uses it.

---

## CLI import scripts

### Bulk AEM reports (2022–2026)

```bash
python3 scripts/import_aem_govau_scan_reports.py \
  ~/Downloads/2022-AEMGovAu-Vulnerability-Scanning-Report.csv \
  ~/Downloads/2023-AEMGovAu-Vulnerability-Scanning-Report.csv \
  ~/Downloads/2024-AEMGovAu-Vulnerability-Scanning-Report.csv \
  ~/Downloads/2025-AEMGovAu-Vulnerability-Scanning-Report.csv \
  ~/Downloads/2026-AEMGovAu-Vulnerability-Scanning-Report.csv
```

### Splunk Nexpose (one or two files per week)

```bash
python3 scripts/import_splunk_scan_reports.py \
  ~/Downloads/AMSGovCloud_M2-Prod-2026-05-14.csv \
  ~/Downloads/AMSGovCloud_Cust_SA_Acct-2026-05-14.csv
```

Use `--dry-run` to parse without writing.

---

## Charts and filters

| Tab | What it shows |
|-----|----------------|
| **Overview** | Last 20 weeks TTV; full-history TTV (with range slider); yearly M2/SA/EKS means |
| **Trends** | **Weekly snapshots** — one point per scan week (TTV and per-server) |
| **Trends** | **Monthly comparison** — one averaged point per month per year (May = average of all May weeks) |
| **By environment** | M2 vs SA per-server (latest year) |
| **Data** | Full weekly table |

**Years** multiselect: must include **2026** (and recent years) to see May 2026 weeks. The app auto-adds the latest year when new data is imported; **Reload data** resets the filter to all years.

---

## Metrics definitions

| Metric | Meaning |
|--------|---------|
| **M2 TTV** | Total vulnerability findings (rows) for M2-Prod from Splunk/AEM |
| **SA TTV** | Total findings for Cust SA Acct |
| **Container vul count** | EKS cluster `EKS_AEMGovAU_PROD_Cluster` (AEM **M2-Containers** column) |
| **Per server** | TTV ÷ server count for that environment |

---

## Deploying data to Streamlit Cloud

1. Commit updated `data/server_vulnerabilities_legacy/` (or run collectors + upload locally, then push).
2. `./scripts/publish_streamlit_github.sh` includes legacy data paths.
3. See [STREAMLIT_CLOUD.md](STREAMLIT_CLOUD.md).

Trend Micro JSONL under `data/*_metrics.jsonl` is updated by GitHub Actions; **legacy weekly data is updated by AEM/Splunk import or UI upload**, not by the Trend Micro collector workflow.

---

## Release 1.0.11 summary

- Splunk Nexpose CSV parser and merge into weekly metrics  
- Multi-file drag-and-drop upload on Legacy tab  
- Weekly snapshot trend charts (May 8 / May 15 visible as distinct weeks)  
- Year filter sync and “last 20 weeks” overview chart  
- Real uploads exempt from AEM projected-data cutoff  
- Dashboard branding footer and version display  

---

[Back to INDEX](INDEX.md) · [CHANGELOG](CHANGELOG.md) · [TROUBLESHOOTING](TROUBLESHOOTING.md)
