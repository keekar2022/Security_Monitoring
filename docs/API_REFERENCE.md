# API & Vulnerability Reference

Reference for Trend Micro Vision One APIs used by this project and notes on vulnerability data. Replaces API_COMPARISON, API_DATA_AVAILABILITY_REPORT, API_STATUS_NOTE, ASRM_VULNERABLE_DEVICES_API, and VULNERABILITY_* docs.

---

## APIs Used

| Feature | API / Endpoint | Purpose |
|--------|-----------------|---------|
| Container vulnerabilities | `GET /beta/containerSecurity/vulnerabilities` | Cluster-level vulnerability counts and risk scores |
| Endpoint inventory (OAT) | OAT detections API | Endpoints with detections, stats |
| Endpoint/device vulnerabilities | ASRM Device Vulnerabilities | Per-device CVE and severity (needs ASRM permissions) |
| ASRM vulnerable devices | `GET /v3.0/asrm/vulnerableDevices` | Device list and CVE data (with token from pass) |

---

## Data Availability

- **Container Security**: Requires Container Security and cluster view permissions; data per cluster/group.
- **Endpoint inventory**: From OAT detections; only endpoints with recent detections.
- **Endpoint vulnerabilities**: Requires Attack Surface Risk Management / Endpoint Inventory / Risk Insights (and optionally Device Risk Assessment) permissions.

---

## Vulnerability Counts & Comparisons

- Portal and API counts can differ due to filters, timing, and aggregation (e.g. cluster vs image).
- For comparison with portal exports, use the same environment and date; prefer API as source of record for automation.
- Beta endpoints (e.g. `/beta/containerSecurity/vulnerabilities`) may change; monitor for deprecations.

---

## Base URLs

- US/Global: `https://api.xdr.trendmicro.com`
- Australia: `https://api.au.xdr.trendmicro.com`

Configured in `config/environments.json` and via Pass (`TrendMicro/ENV/api_base_url`).

---

[Back to INDEX](INDEX.md)
