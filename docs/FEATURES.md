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
