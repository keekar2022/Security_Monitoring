# Changelog & Fixes

Summary of changes, fixes, and implementation notes. Replaces WHATS_NEW, FIX_SUMMARY, VIEWER_DATA_DISPLAY_FIX, JSONL_DATA_FIX, CSV_LOADING_UPDATE, GO_BIN_COMMANDS_STATUS, and IMPLEMENTATION_SUMMARY.

Dashboard release version is tracked in the root [`VERSION`](../VERSION) file (currently **1.0.11**). Platform / Go suite may use separate versioning in README.
## [1.1.0] - 2026-05-18

Update the dashboard to show data from Legacy Tool scan results



---

## 1.0.11 — 2026-05-18 — AEM Gov AU legacy dashboard & Splunk ingest

### Added

- **Keekar's Security Monitoring Dashboard** title, footer attribution, and build version (`monitoring_dashboard/version_info.py`, `scripts/write_version.py`).
- **ServerVulnerabilities-LegacyTool** tab (first tab): weekly AEM Gov AU trends 2022–2026 (M2, SA, EKS containers).
- **Splunk Nexpose CSV parser** (`monitoring_dashboard/server_vuln_legacy/splunk_report_parser.py`) for `AMSGovCloud_M2-Prod-*.csv` and `AMSGovCloud_Cust_SA_Acct-*.csv`.
- **CLI:** `scripts/import_splunk_scan_reports.py` — merge M2 + SA Splunk exports into one weekly row.
- **UI upload:** drag-and-drop, **multi-file** processing, upload ledger display.
- **Trends:** weekly snapshot charts (TTV and per-server by `scan_date`); monthly year-overlay charts retained.
- **Overview:** “last 20 weeks” TTV chart; full-history chart with range slider.
- **Data:** Splunk May 2026 weeks in `weekly_metrics.jsonl` (`2026-05-08`, `2026-05-15`).

### Changed

- Bulk AEM import still excludes projected rows from **2026-05-13** onward; **manual uploads and Splunk files are not blocked** by that cutoff.
- Year multiselect auto-includes the latest year when new data appears; **Reload data** resets year selection.

### Fixed

- May 14 Splunk exports rejected by projected-data cutoff (now ingested as week `2026-05-15`).
- Trend charts showing only monthly May average instead of individual weeks **8 May** and **15 May**.
- Year filter session state omitting **2026** after new uploads.

📚 Full guide: [AEM_GOVAU_LEGACY_DASHBOARD.md](AEM_GOVAU_LEGACY_DASHBOARD.md)

---

## Recent Highlights

- **Go implementation**: API server and CLI tools (container vulns, endpoint inventory, endpoint vulns) are the primary implementation. Python/Node/Rust references may remain in docs for context.
- **Streamlit dashboard**: Trend Micro JSONL tabs plus AEM Gov AU legacy weekly tab; deploy via [STREAMLIT_CLOUD.md](STREAMLIT_CLOUD.md).
- **Docker**: Image with in-image pass store; `export-pass-for-docker.sh` to bake tokens; sync scripts for Mac/Windows.
- **Pass & tokens**: Single-line token storage enforced to avoid HTTP 401; helper scripts `update-pass-credential.sh` and `verify_pass_tokens.sh`.
- **Docs**: Consolidated into fewer files (INDEX, QUICK_START_GUIDE, CONFIGURATION, PASS_AND_CREDENTIALS, FEATURES, API_REFERENCE, MONITORING, MIGRATION, BEST_PRACTICES, TROUBLESHOOTING, CHANGELOG, AEM_GOVAU_LEGACY_DASHBOARD).

---

## Fixes (Summarized)

- **Viewer data display**: Aligned with JSONL structure and API responses.
- **JSONL data**: Correct parsing and field names for Grafana/consumers.
- **CSV loading**: Consistent headers and encoding.
- **HTTP 500 handling**: Improved error logging and response body capture for container vulnerability API.
- **Go binaries**: Built via `go/Makefile`; binaries in `go/bin/`; Docker image includes all CLI tools and pass helpers.

---

## Version History

| Version | Date | Focus |
|---------|------|--------|
| **1.0.11** | 2026-05-18 | Splunk ingest, multi-file upload, weekly legacy trends |
| **1.0.10** | 2026-05-17 | AEM Gov AU bulk import (2022–2026), legacy tab schema v2 |
| **1.0.x** | 2026 | Streamlit dashboard, Okta OIDC, scheduled collection |
| **6.x** | 2026 | Go-based platform, Docker, consolidated docs |
| **5.x** | — | Multi-language support, Cursor rules |
| **4.x** | — | OpenTelemetry, Grafana/Loki, container vulnerability scanning |

---

[Back to INDEX](INDEX.md)
