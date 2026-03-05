# Endpoint Inventory & Statistics Guide

**Author:** Mukesh Kesharwani (mkesharw@adobe.com)  
**Version:** 2.0.0  
**Last Updated:** January 27, 2026

---

## Overview

The `get_endpoint_stats.py` script extracts comprehensive endpoint inventory and security statistics from OAT (Observed Attack Techniques) detection data. It provides visibility into endpoints with recent security events across all your environments.

### What This Script Provides

✅ **Available Now** (No Additional Setup Required):
- Endpoint inventory from security detections
- Endpoint names, GUIDs, IP addresses, MAC addresses
- Operating system information (name, version, description)
- Trend Micro product/agent versions
- Security detection counts by severity (Critical, High, Medium, Low, Info)
- Risk scores per endpoint
- MITRE ATT&CK tactic and technique coverage
- Multi-environment support
- Standard output formats (CSV, TXT, JSONL)
- Grafana/Loki integration ready

❌ **Not Included** (Requires ASRM Module):
- CVE vulnerability lists
- Patch status
- Vulnerability severity counts
- Complete endpoint inventory (only endpoints with detections shown)

---

## Quick Start

### Basic Usage

```bash
# Scan all environments
python3 get_endpoint_stats.py

# Scan specific environment
python3 get_endpoint_stats.py --environment quality_test

# Scan multiple environments
python3 get_endpoint_stats.py -e quality_test -e production_au

# Quiet mode (for cron/automation)
python3 get_endpoint_stats.py --quiet

# Summary to console only (no files)
python3 get_endpoint_stats.py --summary-only
```

### Output Files Generated

1. **`endpoint_inventory_summary.csv`** - Excel/database ready
2. **`endpoint_inventory_report.txt`** - Human-readable report
3. **`endpoint_inventory_metrics.jsonl`** - Grafana/Loki integration

---

## Understanding the Data

### Data Source: OAT Detections

This script uses the **OAT (Observed Attack Techniques) API** which tracks security events/detections on endpoints. 

**What does this mean?**
- Only endpoints with **recent security detections** appear in the inventory
- If an endpoint has no detections, it won't be included
- This is NOT a complete asset inventory (requires ASRM for that)
- Detection counts indicate security activity, not vulnerabilities

### Detection Risk Levels

| Level | Weight | Meaning |
|-------|--------|---------|
| **Critical** | 10 points | Highest priority security event |
| **High** | 5 points | Significant security concern |
| **Medium** | 2 points | Moderate security event |
| **Low** | 1 point | Minor security observation |
| **Info** | 0 points | Informational only |

**Risk Score** = (Critical × 10) + (High × 5) + (Medium × 2) + (Low × 1)

---

## Command Reference

### All Command-Line Options

```bash
python3 get_endpoint_stats.py [OPTIONS]

Options:
  -e, --environment ENV     Environment to scan (can use multiple times)
                           Choices: production, production_au, quality_test,
                                    staging, development
  
  -o, --output FILE        Text report output file
                           Default: endpoint_inventory_report.txt
  
  --csv-output FILE        CSV summary output file
                           Default: endpoint_inventory_summary.csv
  
  --otel-output FILE       JSONL (OTel) output file
                           Default: endpoint_inventory_metrics.jsonl
  
  -q, --quiet              Suppress progress messages
  
  --summary-only           Display summary to console only (no files)
  
  -h, --help               Show help message
```

### Examples

```bash
# Scan production environments only
python3 get_endpoint_stats.py -e production -e production_au

# Custom output file names
python3 get_endpoint_stats.py \
  --output my_endpoint_report.txt \
  --csv-output my_endpoints.csv \
  --otel-output my_endpoint_metrics.jsonl

# Quick summary view (no files)
python3 get_endpoint_stats.py --summary-only

# Automation-friendly (quiet, append to existing files)
python3 get_endpoint_stats.py --quiet
```

---

## Output Formats

### 1. CSV Format (`endpoint_inventory_summary.csv`)

**Use for:** Excel, Google Sheets, database import, data analysis

**Columns:**
- `timestamp` - When the scan was performed
- `environment` - Environment label
- `business_name` - Trend Micro business/account name
- `region` - Region (us, au, etc.)
- `endpoint_guid` - Unique endpoint identifier
- `endpoint_name` - Hostname
- `ip_addresses` - IP addresses (comma-separated)
- `mac_addresses` - MAC addresses (comma-separated)
- `os_name` - Operating system
- `os_version` - OS version
- `product` - Trend Micro product and version
- `total_detections` - Total security detections
- `critical_detections` - Critical severity count
- `high_detections` - High severity count
- `medium_detections` - Medium severity count
- `low_detections` - Low severity count
- `info_detections` - Info severity count
- `risk_score` - Calculated risk score
- `entity_types` - Types (e.g., endpoint, container)
- `sources` - Data sources
- `mitre_tactics_count` - Number of MITRE tactics observed
- `mitre_techniques_count` - Number of MITRE techniques observed
- `first_seen` - Earliest detection timestamp
- `last_seen` - Most recent detection timestamp

**Example:**
```csv
timestamp,environment,endpoint_name,os_name,total_detections,risk_score
2026-01-27T00:00:55Z,Quality & Test,QualcommCN-dev-dispatcher1,Linux,109,19
```

### 2. Text Format (`endpoint_inventory_report.txt`)

**Use for:** Human consumption, email reports, quick review

**Sections:**
1. **Header** - Report metadata, environment, business info
2. **Summary** - Overall statistics, detection counts
3. **Endpoint Details** - Tabular view of all endpoints
4. **Top 10 Highest Risk** - Detailed info on high-risk endpoints
5. **Important Notes** - Explanation of data source and limitations

**Example:**
```
SUMMARY
------------------------------------
Total Endpoints:           2
Total Detections:          218
  Critical Risk:           0
  High Risk:               0
  Medium Risk:             2
  Low Risk:                34
```

### 3. JSONL Format (`endpoint_inventory_metrics.jsonl`)

**Use for:** Grafana, Loki, Prometheus, time-series analysis

**OpenTelemetry-compliant structure:**
```json
{
  "Timestamp": "2026-01-27T00:00:55.210612+00:00",
  "service.name": "trend-vision-one-endpoint-inventory",
  "deployment.environment": "Quality & Test",
  "endpoint.guid": "1282573b-8d6e-48a1-adb5-247a3b583f8d",
  "endpoint.name": "QualcommCN-dev-dispatcher1cnnorth1-b86",
  "endpoint.ips": ["10.43.0.22"],
  "detections.total": 109,
  "detections.critical": 0,
  "detections.high": 0,
  "detections.medium": 1,
  "detections.low": 17,
  "detections.risk_score": 19,
  "mitre.tactics.count": 7,
  "mitre.techniques.count": 9
}
```

---

## Automation & Scheduling

### Cron Jobs

```bash
# Edit crontab
crontab -e

# Scan all environments daily at 2 AM
0 2 * * * cd /path/to/Integration-API-Dev && python3 get_endpoint_stats.py --quiet

# Scan production environments every 6 hours
0 */6 * * * cd /path/to/Integration-API-Dev && python3 get_endpoint_stats.py -e production -e production_au --quiet

# Weekly full report (email results)
0 8 * * 1 cd /path/to/Integration-API-Dev && python3 get_endpoint_stats.py | mail -s "Weekly Endpoint Inventory" your.email@company.com
```

### Systemd Timer

```bash
# /etc/systemd/system/endpoint-inventory.service
[Unit]
Description=Trend Micro Endpoint Inventory Scan
After=network.target

[Service]
Type=oneshot
User=mkesharw
WorkingDirectory=/path/to/Integration-API-Dev
ExecStart=/usr/bin/python3 get_endpoint_stats.py --quiet

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/endpoint-inventory.timer
[Unit]
Description=Daily Endpoint Inventory Scan
Requires=endpoint-inventory.service

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Enable:**
```bash
sudo systemctl enable endpoint-inventory.timer
sudo systemctl start endpoint-inventory.timer
```

---

## Grafana Integration

### Promtail Configuration

Add to your `promtail-config.yaml`:

```yaml
scrape_configs:
  - job_name: endpoint_inventory
    static_configs:
      - targets:
          - localhost
        labels:
          job: trend_micro_endpoint_inventory
          __path__: /path/to/Integration-API-Dev/endpoint_inventory_metrics.jsonl
    pipeline_stages:
      - json:
          expressions:
            timestamp: Timestamp
            environment: deployment.environment
            endpoint_name: endpoint.name
            detections_total: detections.total
            detections_critical: detections.critical
            detections_high: detections.high
            risk_score: detections.risk_score
      - timestamp:
          source: timestamp
          format: RFC3339
```

### LogQL Queries

```logql
# All endpoint inventory entries
{job="trend_micro_endpoint_inventory"}

# High-risk endpoints (risk score > 50)
{job="trend_micro_endpoint_inventory"} | json | risk_score > 50

# Endpoints with critical detections
{job="trend_micro_endpoint_inventory"} | json | detections_critical > 0

# Group by environment
sum by (environment) (count_over_time({job="trend_micro_endpoint_inventory"}[24h]))

# Top 10 endpoints by detection count
topk(10, sum by (endpoint_name) (detections_total))
```

### Grafana Dashboard Panels

**1. Endpoint Count by Environment**
```
Query: count by (deployment_environment) ({job="trend_micro_endpoint_inventory"})
Type: Bar Chart
```

**2. Detection Count Over Time**
```
Query: sum(detections_total) by (deployment_environment)
Type: Time Series
```

**3. Risk Score Distribution**
```
Query: histogram_quantile(0.95, sum(rate(detections_risk_score[5m])) by (le))
Type: Gauge
```

---

## Comparison: Endpoint Stats vs Container Vulnerabilities

| Feature | Endpoint Stats (OAT) | Container Vulnerabilities |
|---------|---------------------|---------------------------|
| **Data Source** | OAT Detections API | Container Security API |
| **What It Shows** | Security event detections | CVE vulnerabilities |
| **Severity** | Detection risk level | CVE severity (CVSS) |
| **Coverage** | Endpoints with detections | All container images |
| **Requires Setup** | ❌ No (works now) | ✅ Yes (done) |
| **Patch Status** | ❌ No | ❌ No (both need ASRM) |
| **MITRE ATT&CK** | ✅ Yes | ❌ No |
| **Risk Scoring** | ✅ Yes | ✅ Yes |
| **Multi-Env** | ✅ Yes | ✅ Yes |
| **CSV/TXT/JSONL** | ✅ Yes | ✅ Yes |

---

## Troubleshooting

### No Endpoints Found

**Symptoms:**
```
⚠️  No detections found
```

**Possible Causes:**
1. No security detections in the time period
2. API token expired or invalid
3. No Trend Micro agents installed on endpoints

**Solutions:**
1. Check Trend Vision One console for detections
2. Verify token: `./verify_pass_tokens.sh`
3. Confirm endpoints are enrolled in Vision One

### Different Counts Across Environments

**Q:** Why do Quality & Test and Production AU show the same endpoint?

**A:** This can happen if:
- The same physical/virtual machine is enrolled in multiple Trend Micro accounts
- Different environments share infrastructure
- Detection data is replicated across regions

This is normal and expected in some architectures.

### Risk Score Seems Low

**Q:** Why is my endpoint risk score only 19 with 109 detections?

**A:** Most detections are **Info** level (0 points). Risk score only counts:
- Critical × 10
- High × 5
- Medium × 2
- Low × 1

Info-level detections don't contribute to risk score.

---

## Next Steps

### To Get Full Vulnerability Scanning

To get CVE vulnerability data (not just security detections):

1. **Enable ASRM Module**
   - Contact Trend Micro account manager
   - Request: Attack Surface Risk Management
   - This is a licensed add-on module

2. **Once ASRM is enabled:**
   - Use `get_endpoint_vulnerabilities.py` instead
   - Get CVE lists, patch status, vulnerability severity
   - Get complete endpoint inventory (not just endpoints with detections)

3. **Documentation:**
   - See `ENDPOINT_VULNERABILITIES_README.md` for details
   - Run: `python3 get_endpoint_vulnerabilities.py --setup-help`

---

## Support

### Internal Contact
- **Author**: Mukesh Kesharwani
- **Email**: mkesharw@adobe.com

### Trend Micro Resources
- **Portal**: Your regional portal (US/AU)
- **API Docs**: https://automation.trendmicro.com/xdr/api-v3/
- **OAT API**: https://automation.trendmicro.com/xdr/api-v3/#tag/Observed-Attack-Techniques

---

**Last Updated:** January 27, 2026 | **Version:** 2.0.0
