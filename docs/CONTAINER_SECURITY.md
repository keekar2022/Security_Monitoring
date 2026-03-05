# Container Security - Vulnerability Management

**Script:** `get_container_vulnerabilities.py`  
**Version:** 4.0  
**Last Updated:** January 21, 2026  
**Status:** Production Ready  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Output Formats](#output-formats)
3. [Quick Start](#quick-start)
4. [Command-Line Options](#command-line-options)
5. [Use Cases](#use-cases)
6. [Automation](#automation)
7. [Data Analysis](#data-analysis)
8. [Troubleshooting](#troubleshooting)
9. [API Details](#api-details)

---

## Overview

The Container Security vulnerability scanner automatically discovers all Kubernetes clusters and groups in your Trend Micro Vision One environment, fetches vulnerability data, and generates **three standardized output formats** with identical data.

### Key Features

- ✅ **Three standardized output formats** (CSV, TXT, JSONL)
- ✅ **Multi-environment support** (Quality/Test, Production, Production AU)
- ✅ **Automatic cluster discovery** across all environments
- ✅ **Cluster-level granularity** for detailed analysis
- ✅ **Historical tracking** (append mode by default)
- ✅ **Severity breakdown** (Critical, High, Medium, Low)
- ✅ **Risk score calculation** for prioritization
- ✅ **OpenTelemetry format** for Grafana/Loki integration
- ✅ **Pagination handling** for large datasets
- ✅ **Secure credential management** using `pass` (GPG-encrypted)
- ✅ **Token expiry checking** with warnings
- ✅ **Automated reporting** ready for cron

---

## Output Formats

All three formats contain **identical vulnerability data**:

### 1. CSV Format (`container_vulnerability_summary.csv`)

**Purpose:** Data analysis, Excel, databases, pivot tables

**Structure:** One row per cluster

**Columns:**
- Timestamp (ISO 8601)
- Environment (Quality & Test, Production, etc.)
- Business Name (Trend Micro account)
- Region (au, us, etc.)
- Group ID (UUID)
- Group Name (human-readable)
- Cluster ID (unique identifier)
- Cluster Name (human-readable)
- Total (total vulnerabilities)
- Critical (count)
- High (count)
- Medium (count)
- Low (count)
- Risk Score (weighted metric)

**Example:**
```csv
Timestamp,Environment,Business Name,Region,Group ID,Group Name,Cluster ID,Cluster Name,Total,Critical,High,Medium,Low,Risk Score
2026-01-21T02:00:15.123456+00:00,Production,Adobe-AMS-Global,us,f3d39a0e-2ef2-11f0-877b-9ef7334033f5,Ungrouped,AMS_EKS_Zubin_Basic-...,AMS_EKS_Zubin_Basic,403,9,102,195,32,1022
```

### 2. TXT Format (`container_vulnerability_report.txt`)

**Purpose:** Human-readable reports, email, documentation

**Structure:** Fixed-width table with metadata

**Features:**
- Clean table format
- Environment details section
- Summary statistics
- Portal and API URLs
- Business IDs and metadata

**Example:**
```
Environment               Business Name             Region     Group Name           Cluster Name              Total   Crit  High  Med   Low   Risk  
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
Production                Adobe-AMS-Global          us         Ungrouped            AMS_EKS_Zubin_Basic       403     9     102   195   32    1022
```

### 3. JSONL Format (`container_vulnerability_metrics.jsonl`)

**Purpose:** Time-series analysis, Grafana, Loki, alerting

**Structure:** OpenTelemetry Logs Data Model (one JSON object per line)

**Features:**
- ISO 8601 timestamps
- Resource metadata (environment, business, region)
- Attributes (cluster info, vulnerability metrics)
- Aggregation level tags (cluster/group)
- Risk score for trending

**Example:**
```json
{
  "Timestamp": "2026-01-21T02:00:15.123456Z",
  "Body": "Container Security vulnerability scan for cluster 'AMS_EKS_Zubin_Basic'",
  "Resource": {
    "deployment.environment": "Production",
    "cloud.account.name": "Adobe-AMS-Global",
    "cloud.account.id": "ec367c49-2f23-49a3-a55c-a062f7d6583a",
    "cloud.region": "us"
  },
  "Attributes": {
    "group.id": "f3d39a0e-2ef2-11f0-877b-9ef7334033f5",
    "group.name": "Ungrouped",
    "cluster.id": "AMS_EKS_Zubin_Basic-xyz123",
    "cluster.name": "AMS_EKS_Zubin_Basic",
    "vulnerability.total": 403,
    "vulnerability.severity.critical": 9,
    "vulnerability.severity.high": 102,
    "vulnerability.severity.medium": 195,
    "vulnerability.severity.low": 32,
    "vulnerability.risk_score": 1022,
    "aggregation.level": "cluster"
  }
}
```

**See:** [`docs/OTEL_GRAFANA_GUIDE.md`](OTEL_GRAFANA_GUIDE.md) for complete Grafana integration instructions

---

## Quick Start

### Basic Usage

```bash
# Scan all environments, generate all three formats
python3 get_container_vulnerabilities.py

# Files generated:
# ✅ container_vulnerability_summary.csv
# ✅ container_vulnerability_report.txt  
# ✅ container_vulnerability_metrics.jsonl

# Scan specific environment
python3 get_container_vulnerabilities.py --environment production

# Scan specific environment and group
python3 get_container_vulnerabilities.py --environment quality_test --group-name "Ungrouped"

# Quiet mode (for automation)
python3 get_container_vulnerabilities.py --quiet

# Overwrite files instead of append
python3 get_container_vulnerabilities.py --overwrite
```

### View Results

```bash
# View TXT report (human-readable)
cat container_vulnerability_report.txt

# View CSV in terminal
column -t -s',' < container_vulnerability_summary.csv | less -S

# View latest JSONL entry
tail -1 container_vulnerability_metrics.jsonl | python3 -m json.tool

# Count cluster entries
grep -c '"aggregation.level": "cluster"' container_vulnerability_metrics.jsonl
```

---

## Command-Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--environment` | `-e` | Environment(s) to scan (can specify multiple) | All configured |
| `--group-id` | `-g` | Filter by specific group ID | All groups |
| `--group-name` | `-n` | Filter by specific group name | All groups |
| `--output` | `-o` | TXT output file path | `container_vulnerability_report.txt` |
| `--csv-output` | - | CSV output file path | `container_vulnerability_summary.csv` |
| `--otel-output` | - | JSONL output file path | `container_vulnerability_metrics.jsonl` |
| `--no-csv` | - | Disable CSV generation | CSV enabled |
| `--no-otel` | - | Disable JSONL generation | JSONL enabled |
| `--quiet` | `-q` | Suppress progress messages | Verbose |
| `--summary-only` | `-s` | Console output only (no files) | Generate files |
| `--overwrite` | - | Overwrite files instead of append | Append mode |

### Examples

```bash
# Scan production only
python3 get_container_vulnerabilities.py --environment production

# Scan multiple specific environments
python3 get_container_vulnerabilities.py -e quality_test -e production

# Scan specific group in all environments
python3 get_container_vulnerabilities.py --group-name "Ungrouped"

# Custom output files
python3 get_container_vulnerabilities.py \
  --output custom_report.txt \
  --csv-output custom_summary.csv \
  --otel-output custom_metrics.jsonl

# Generate only TXT and CSV (no JSONL)
python3 get_container_vulnerabilities.py --no-otel

# Generate only JSONL (for Grafana)
python3 get_container_vulnerabilities.py --no-csv -o /dev/null

# Fresh start (overwrite all files)
python3 get_container_vulnerabilities.py --overwrite

# Automation mode (quiet, append)
python3 get_container_vulnerabilities.py --quiet
```

---

## Use Cases

### 1. Daily Monitoring

**Goal:** Track vulnerability changes daily across all environments

```bash
# Add to crontab (runs daily at 2 AM)
0 2 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet

# View daily history
grep "Generated:" container_vulnerability_report.txt

# Extract daily totals
grep "^Total Clusters:" container_vulnerability_report.txt
```

### 2. Environment-Specific Monitoring

**Goal:** Track specific environment separately

```bash
# Production monitoring (every 6 hours)
0 */6 * * * cd /path/to/Integration-API-Dev && \
  python3 get_container_vulnerabilities.py \
    --environment production \
    --output prod_vulnerabilities.txt \
    --csv-output prod_summary.csv \
    --otel-output prod_metrics.jsonl \
    --quiet

# Staging monitoring (daily)
0 8 * * * cd /path/to/Integration-API-Dev && \
  python3 get_container_vulnerabilities.py \
    --environment quality_test \
    --output stage_vulnerabilities.txt \
    --csv-output stage_summary.csv \
    --otel-output stage_metrics.jsonl \
    --quiet
```

### 3. Alert on Critical Vulnerabilities

**Goal:** Get notified when critical vulnerabilities are detected

```bash
#!/bin/bash
# vulnerability_alert.sh

cd /path/to/Integration-API-Dev

# Run scan
python3 get_container_vulnerabilities.py --quiet

# Check for critical vulnerabilities in latest scan
CRITICAL_COUNT=$(tail -20 container_vulnerability_report.txt | \
  grep "Total Vulnerabilities:" | \
  sed -n 's/.*Critical: \([0-9]*\).*/\1/p')

if [ "$CRITICAL_COUNT" -gt 0 ]; then
    # Send alert
    echo "ALERT: $CRITICAL_COUNT critical vulnerabilities detected!" | \
      mail -s "Critical Vulnerability Alert" security-team@company.com
    
    # Attach latest CSV report
    tail -20 container_vulnerability_summary.csv | \
      mail -s "Vulnerability Report" -a container_vulnerability_summary.csv \
        security-team@company.com
fi
```

Add to crontab:
```bash
0 */6 * * * /path/to/vulnerability_alert.sh
```

### 4. Weekly Fresh Report

**Goal:** Start with a clean report each week

```bash
# Archive and restart (runs Monday at 8 AM)
0 8 * * 1 cd /path/to/Integration-API-Dev && \
  WEEK=$(date +%Y-W%U) && \
  mkdir -p archive/${WEEK} && \
  mv container_vulnerability_*.{txt,csv,jsonl} archive/${WEEK}/ 2>/dev/null && \
  python3 get_container_vulnerabilities.py --quiet
```

### 5. Cluster Comparison Analysis

**Goal:** Compare vulnerability counts across clusters

```bash
# Generate comparison CSV
jq -r 'select(.Attributes.aggregation.level == "cluster") | 
  [.Attributes."cluster.name", 
   .Attributes."vulnerability.total", 
   .Attributes."vulnerability.severity.critical", 
   .Attributes."vulnerability.risk_score"] | @csv' \
  container_vulnerability_metrics.jsonl | \
  sort -t',' -k2 -nr > cluster_comparison.csv

# View top 10 clusters by vulnerability count
head -10 cluster_comparison.csv | column -t -s','
```

### 6. Risk Score Trending

**Goal:** Track risk score changes over time

```bash
# Extract risk scores for specific cluster
jq -r 'select(.Attributes."cluster.name" == "AMS_EKS_Zubin_Basic") | 
  [.Timestamp, .Attributes."vulnerability.risk_score"] | @csv' \
  container_vulnerability_metrics.jsonl > risk_trend.csv

# Calculate risk score change
awk -F',' 'NR>1{print $2-prev, $1} {prev=$2}' risk_trend.csv
```

### 7. Multi-Environment Dashboard

**Goal:** Compare environments side-by-side

```bash
# Generate environment comparison
jq -s 'group_by(.Resource."deployment.environment") | 
  map({
    environment: .[0].Resource."deployment.environment", 
    clusters: length,
    total_vulnerabilities: map(.Attributes."vulnerability.total") | add,
    critical: map(.Attributes."vulnerability.severity.critical") | add
  })' container_vulnerability_metrics.jsonl | \
  jq -r '.[] | [.environment, .clusters, .total_vulnerabilities, .critical] | @csv'
```

---

## Automation

### Cron Job Examples

```bash
# Edit crontab
crontab -e
```

#### Basic Monitoring (Every 6 hours)
```bash
0 */6 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet
```

#### Daily Report (2 AM)
```bash
0 2 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet
```

#### Weekly Fresh Start (Monday 8 AM)
```bash
0 8 * * 1 cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --overwrite --quiet
```

#### Hourly Production Monitoring
```bash
0 * * * * cd /path/to/Integration-API-Dev && \
  python3 get_container_vulnerabilities.py \
    --environment production \
    --output prod_vulns.txt \
    --otel-output prod_metrics.jsonl \
    --quiet
```

### Systemd Timer (Alternative to Cron)

Create `/etc/systemd/system/vulnerability-scan.service`:

```ini
[Unit]
Description=Trend Micro Vulnerability Scan
After=network.target

[Service]
Type=oneshot
User=your-user
WorkingDirectory=/path/to/Integration-API-Dev
ExecStart=/usr/bin/python3 get_container_vulnerabilities.py --quiet
StandardOutput=journal
StandardError=journal
```

Create `/etc/systemd/system/vulnerability-scan.timer`:

```ini
[Unit]
Description=Run vulnerability scan every 6 hours
Requires=vulnerability-scan.service

[Timer]
OnCalendar=*-*-* 00/6:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable vulnerability-scan.timer
sudo systemctl start vulnerability-scan.timer

# Check status
sudo systemctl status vulnerability-scan.timer
sudo systemctl list-timers vulnerability-scan.timer
```

---

## Data Analysis

### CSV Analysis (Excel/Pandas)

#### In Excel

1. Open `container_vulnerability_summary.csv`
2. Create Pivot Table:
   - Rows: Cluster Name
   - Values: Total, Critical, High, Medium, Low
   - Sort by Total (descending)
3. Create charts for visualization

#### Using Pandas (Python)

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load CSV
df = pd.read_csv('container_vulnerability_summary.csv')

# Convert timestamp to datetime
df['Timestamp'] = pd.to_datetime(df['Timestamp'])

# Group by cluster and calculate trends
cluster_trends = df.groupby(['Cluster Name', 'Timestamp']).agg({
    'Total': 'sum',
    'Critical': 'sum',
    'High': 'sum',
    'Risk Score': 'sum'
}).reset_index()

# Plot vulnerability trend for specific cluster
cluster_data = cluster_trends[cluster_trends['Cluster Name'] == 'AMS_EKS_Zubin_Basic']
plt.plot(cluster_data['Timestamp'], cluster_data['Total'])
plt.title('Vulnerability Trend - AMS_EKS_Zubin_Basic')
plt.xlabel('Date')
plt.ylabel('Total Vulnerabilities')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('vulnerability_trend.png')

# Calculate environment statistics
env_stats = df.groupby('Environment').agg({
    'Total': 'sum',
    'Critical': 'sum',
    'High': 'sum',
    'Risk Score': 'sum'
})
print(env_stats)
```

### TXT Analysis (Shell)

```bash
# Count total scans performed
grep -c "Generated:" container_vulnerability_report.txt

# List all scan timestamps
grep "Generated:" container_vulnerability_report.txt

# Extract cluster vulnerability counts
grep -E "^[A-Z]" container_vulnerability_report.txt | \
  awk '{print $1, $2, $3}' | \
  column -t

# Find clusters with critical vulnerabilities
awk '$7 > 0 {print $5, "has", $7, "critical vulnerabilities"}' \
  < <(tail -n +2 container_vulnerability_summary.csv | tr ',' ' ')
```

### JSONL Analysis (jq)

```bash
# Get latest vulnerability count per cluster
jq -s 'group_by(.Attributes."cluster.name") | 
  map(max_by(.Timestamp)) | 
  .[] | 
  {cluster: .Attributes."cluster.name", 
   total: .Attributes."vulnerability.total", 
   critical: .Attributes."vulnerability.severity.critical"}' \
  container_vulnerability_metrics.jsonl

# Calculate average vulnerabilities per environment
jq -s 'group_by(.Resource."deployment.environment") | 
  map({
    env: .[0].Resource."deployment.environment", 
    avg_total: (map(.Attributes."vulnerability.total") | add / length),
    avg_critical: (map(.Attributes."vulnerability.severity.critical") | add / length)
  })' container_vulnerability_metrics.jsonl

# Find clusters with increasing vulnerabilities
jq -s 'group_by(.Attributes."cluster.name") | 
  map(sort_by(.Timestamp) | 
    {cluster: .[0].Attributes."cluster.name", 
     first: .[0].Attributes."vulnerability.total", 
     last: .[-1].Attributes."vulnerability.total", 
     change: .[-1].Attributes."vulnerability.total" - .[0].Attributes."vulnerability.total"}) | 
  map(select(.change > 0))' \
  container_vulnerability_metrics.jsonl

# Export time-series for specific cluster
jq -r 'select(.Attributes."cluster.name" == "AMS_EKS_Zubin_Basic") | 
  [.Timestamp, .Attributes."vulnerability.total", 
   .Attributes."vulnerability.severity.critical", 
   .Attributes."vulnerability.severity.high"] | @csv' \
  container_vulnerability_metrics.jsonl > cluster_timeseries.csv
```

---

## Troubleshooting

### No Clusters Found

**Symptoms:**
```
❌ No Kubernetes clusters found in 'environment_name'.
```

**Solutions:**
1. Verify clusters exist in Portal:
   - Go to https://portal.au.xdr.trendmicro.com/ (or your region)
   - Navigate to: **Container Security → Kubernetes Clusters**
2. Check API token has Container Security permissions
3. Verify you're scanning the correct environment:
   ```bash
   python3 get_container_vulnerabilities.py --environment production
   ```
4. Check token expiry:
   ```bash
   # Token info is checked automatically, look for warnings in output
   ```

### API Token Expired

**Symptoms:**
```
❌ Error: API token for 'environment' has expired.
```

**Solution:**
1. Generate new token:
   - Go to Portal → **Administration → API Keys**
   - Click **Add** to create new token
   - Copy token value
2. Update credentials:
   ```bash
   # Store in pass vault (recommended)
   pass insert TrendMicro/production/api_token
   
   # Or update deployment_config.json (not recommended for production)
   # Edit config/deployment_config.json
   ```

### Permission Errors

**Symptoms:**
```
[Errno 13] Permission denied: 'container_vulnerability_report.txt'
```

**Solution:**
```bash
# Check file permissions
ls -la container_vulnerability_*.{txt,csv,jsonl}

# Fix permissions
chmod 644 container_vulnerability_*.{txt,csv,jsonl}

# Check directory permissions
ls -ld .

# Fix directory permissions
chmod 755 .
```

### Rate Limit Exceeded

**Symptoms:**
```
⚠️  Rate limit warning or 429 HTTP status
```

**Solution:**
- The script automatically handles rate limits with retry logic
- If persistent, reduce scan frequency:
  ```bash
  # Instead of hourly, run every 6 hours
  0 */6 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet
  ```

### Incomplete Data

**Symptoms:**
- CSV/TXT/JSONL files have different row counts
- Missing clusters in output

**Diagnosis:**
```bash
# Check CSV row count
wc -l container_vulnerability_summary.csv

# Check JSONL cluster entries
grep -c '"aggregation.level": "cluster"' container_vulnerability_metrics.jsonl

# Check TXT cluster entries  
grep -c "^[A-Z].*[0-9]" container_vulnerability_report.txt
```

**Solution:**
- Re-run with `--overwrite` to ensure fresh data:
  ```bash
  python3 get_container_vulnerabilities.py --overwrite
  ```
- Check for script errors (run without `--quiet`)

### Configuration Issues

**Symptoms:**
```
❌ Error: Configuration file not found
```

**Solution:**
```bash
# Verify configuration files exist
ls -la config/

# Required files:
# - config/environments.json
# - config/deployment_config.json

# Check configuration validity
python3 -c "
import json
with open('config/environments.json') as f:
    print('environments.json: OK')
    json.load(f)
with open('config/deployment_config.json') as f:
    print('deployment_config.json: OK')
    json.load(f)
"
```

---

## API Details

### Endpoints Used

#### 1. List Kubernetes Clusters
```
GET /beta/containerSecurity/kubernetesClusters
```

Returns all Kubernetes clusters with metadata:
- Cluster ID
- Cluster Name
- Group ID
- Group Name
- Status
- Last seen timestamp

#### 2. List Vulnerabilities
```
GET /beta/containerSecurity/vulnerabilities
```

Returns container vulnerabilities with pagination:
- CVE name and description
- Risk level (Critical, High, Medium, Low)
- CVSS severity and score
- Affected cluster ID
- Container image details
- Registry information
- First/last detected timestamps
- CVE link

### Authentication

All requests require Bearer token authentication:

```http
Authorization: Bearer YOUR_API_TOKEN
Content-Type: application/json
Accept: application/json
```

Tokens are stored securely in:
- **Recommended:** GPG-encrypted `pass` vault
- **Alternative:** `config/deployment_config.json` (not recommended for production)

### Environments and Regions

| Environment | Region | API Base URL | Portal URL |
|------------|--------|--------------|------------|
| Quality & Test | Australia (au) | https://api.au.xdr.trendmicro.com | https://portal.au.xdr.trendmicro.com/ |
| Production | United States (us) | https://api.xdr.trendmicro.com | https://portal.xdr.trendmicro.com/ |
| Production AU | Australia (au) | https://api.au.xdr.trendmicro.com | https://portal.au.xdr.trendmicro.com/ |

### Rate Limits

- Automatic retry with exponential backoff
- Respects HTTP 429 responses
- Default retry attempts: 3
- Default retry delay: 5 seconds

### Pagination

- Automatic pagination handling
- Default page size: 200 items
- Continues until all data fetched

---

## Best Practices

### Security

- ✅ Use `pass` (GPG-encrypted) for credential storage
- ✅ Never commit API tokens to version control
- ✅ Rotate tokens regularly (every 90 days)
- ✅ Use environment-specific tokens (don't share across environments)
- ✅ Set file permissions to 600 for sensitive files
- ✅ Review vulnerability reports weekly
- ✅ Prioritize Critical and High severity vulnerabilities

### Automation

- ✅ Use `--quiet` flag for cron jobs
- ✅ Redirect output to log files for debugging:
  ```bash
  python3 get_container_vulnerabilities.py --quiet 2>&1 | \
    logger -t vulnerability-scan
  ```
- ✅ Monitor script exit codes in automation
- ✅ Set up alerts for script failures
- ✅ Archive old reports monthly

### Performance

- ✅ Scan during off-peak hours
- ✅ Use appropriate scan frequency (production: 6h, staging: 12h, dev: 24h)
- ✅ Monitor API rate limits
- ✅ Implement file rotation for JSONL files

### Reporting

- ✅ Use append mode (default) for historical tracking
- ✅ Use overwrite mode for weekly summaries
- ✅ Generate separate reports for critical groups
- ✅ Share CSV reports with stakeholders
- ✅ Use TXT reports for email distribution
- ✅ Use JSONL for automated analysis and alerting

---

## Support & Resources

### Documentation

- **Main README:** [`README.md`](../README.md)
- **Grafana Guide:** [`docs/OTEL_GRAFANA_GUIDE.md`](OTEL_GRAFANA_GUIDE.md)
- **Configuration:** [`docs/CONFIGURATION.md`](CONFIGURATION.md)
- **Password Store:** [`docs/PASS_QUICK_REFERENCE.md`](PASS_QUICK_REFERENCE.md)

### Trend Micro Resources

- **Portal:** 
  - Australia: https://portal.au.xdr.trendmicro.com/
  - US/Global: https://portal.xdr.trendmicro.com/
- **API Documentation:** https://automation.trendmicro.com/xdr/api-beta/
- **Support:** https://success.trendmicro.com/

### Business Information

**Quality & Test Environment:**
- Business Name: Adobe Managed Services QTE
- Business ID: c732de94-ce77-4540-89d4-7f5c2c2032f6
- Region: Australia (au)

**Production Environment:**
- Business Name: Adobe-AMS-Global
- Business ID: ec367c49-2f23-49a3-a55c-a062f7d6583a
- Region: United States (us)

**Production AU Environment:**
- Business Name: Adobe-MS-Au
- Business ID: cc305c0c-a560-4fa9-9481-46a77278122e
- Region: Australia (au)

---

**Last Updated:** January 21, 2026  
**Script Version:** 4.0  
**Document Version:** 4.0
