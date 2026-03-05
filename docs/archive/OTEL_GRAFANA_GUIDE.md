# OpenTelemetry & Grafana Integration Guide

**Version:** 4.0  
**Last Updated:** January 21, 2026  
**Status:** Production Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Output Formats](#output-formats)
3. [Quick Start](#quick-start)
4. [Grafana Integration Setup](#grafana-integration-setup)
5. [Dashboard Configuration](#dashboard-configuration)
6. [Query Examples](#query-examples)
7. [Alerting](#alerting)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The Container Security Vulnerability Scanner generates **three standardized output formats**, all containing the same vulnerability data:

1. **CSV** - For Excel, databases, and data analysis
2. **TXT** - For human-readable reports and email
3. **JSONL** - For Grafana, Loki, and time-series analysis

### What is OpenTelemetry?

OpenTelemetry (OTel) is an open-source observability framework for collecting, processing, and exporting telemetry data. By outputting vulnerability data in OTel format, you can:

- ✅ **Track vulnerability trends over time** for each cluster
- ✅ **Create dashboards** showing vulnerability changes
- ✅ **Set up alerts** when critical vulnerabilities spike
- ✅ **Correlate** security data with other observability data
- ✅ **Compare clusters** side-by-side in real-time
- ✅ **Generate reports** from time-series data

---

## Output Formats

All three formats contain **identical vulnerability data** for consistency:

### 1. CSV Format (`container_vulnerability_summary.csv`)

**Best for:** Excel, Google Sheets, databases, pivot tables, data analysis

**Columns:**
- `Timestamp` - When scan was performed (ISO 8601)
- `Environment` - Quality & Test, Production, etc.
- `Business Name` - Trend Micro account name
- `Region` - Geographic region (au, us, etc.)
- `Group ID` - Container Security group UUID
- `Group Name` - Human-readable group name
- `Cluster ID` - Unique cluster identifier
- `Cluster Name` - Human-readable cluster name
- `Total` - Total vulnerabilities
- `Critical` - Critical severity count
- `High` - High severity count
- `Medium` - Medium severity count
- `Low` - Low severity count
- `Risk Score` - Weighted risk score

**Format:** Standard CSV, one row per cluster

**Example:**
```csv
Timestamp,Environment,Business Name,Region,Group ID,Group Name,Cluster ID,Cluster Name,Total,Critical,High,Medium,Low,Risk Score
2026-01-20T21:26:24.726030+00:00,Quality & Test,Adobe Managed Services QTE,Australia (au),f3d39a0e-2ef2-11f0-877b-9ef7334033f5,Ungrouped,AMS_EKS_Stage_01-38Sc5cvwieGJs9cus2sGVU7901c,AMS_EKS_Stage_01,253,2,61,123,23,594
```

### 2. TXT Format (`container_vulnerability_report.txt`)

**Best for:** Email reports, terminal viewing, documentation, human consumption

**Structure:**
- Header with scan metadata
- Table with vulnerability counts per cluster
- Summary statistics
- Additional details section with:
  - Business IDs
  - Portal URLs
  - API endpoints
  - Environment information

**Format:** Fixed-width table with human-readable layout

**Example:**
```
Environment               Business Name             Region     Group Name           Cluster Name              Total   Crit  High  Med   Low   Risk  
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
Quality & Test            Adobe Managed Services Q  au         Ungrouped            AMS_EKS_Stage_01          253     2     61    123   23    594
```

### 3. JSONL Format (`container_vulnerability_metrics.jsonl`)

**Best for:** Grafana, Loki, Prometheus, time-series analysis, trending, alerting

**Structure:** OpenTelemetry Logs Data Model

**Fields:**
- `Timestamp` - ISO 8601 timestamp
- `Resource` - Service and environment metadata
  - `deployment.environment`
  - `cloud.account.name` (Business Name)
  - `cloud.account.id` (Business ID)
  - `cloud.region`
- `Attributes` - Vulnerability metrics and identifiers
  - `group.id`, `group.name`
  - `cluster.id`, `cluster.name`
  - `vulnerability.total`
  - `vulnerability.severity.critical/high/medium/low`
  - `vulnerability.risk_score`
  - `aggregation.level` - "cluster" or "group"

**Format:** One JSON object per line (JSON Lines)

**Example:**
```json
{
  "Timestamp": "2026-01-20T21:26:24.726030Z",
  "Body": "Container Security vulnerability scan for cluster 'AMS_EKS_Stage_01'",
  "Resource": {
    "deployment.environment": "Quality & Test",
    "cloud.account.name": "Adobe Managed Services QTE",
    "cloud.account.id": "c732de94-ce77-4540-89d4-7f5c2c2032f6",
    "cloud.region": "au"
  },
  "Attributes": {
    "group.id": "f3d39a0e-2ef2-11f0-877b-9ef7334033f5",
    "group.name": "Ungrouped",
    "cluster.id": "AMS_EKS_Stage_01-38Sc5cvwieGJs9cus2sGVU7901c",
    "cluster.name": "AMS_EKS_Stage_01",
    "vulnerability.total": 253,
    "vulnerability.severity.critical": 2,
    "vulnerability.severity.high": 61,
    "vulnerability.severity.medium": 123,
    "vulnerability.severity.low": 23,
    "vulnerability.risk_score": 594,
    "aggregation.level": "cluster"
  }
}
```

### Risk Score Calculation

The `vulnerability.risk_score` is calculated as:

```
risk_score = (critical × 10) + (high × 5) + (medium × 2) + (low × 1)
```

This provides a single metric that weighs critical vulnerabilities more heavily, making it easier to track overall security posture.

---

## Quick Start

### 1. Generate All Formats

```bash
# Generate all three formats (CSV, TXT, JSONL)
python3 get_container_vulnerabilities.py

# Files created:
# - container_vulnerability_summary.csv
# - container_vulnerability_report.txt
# - container_vulnerability_metrics.jsonl
```

### 2. Schedule Regular Scans

For time-series analysis in Grafana, schedule regular scans:

```bash
# Add to crontab for hourly scans
crontab -e

# Run every hour
0 * * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet

# Run every 6 hours
0 */6 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet

# Run daily at 2 AM
0 2 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet
```

### 3. View Time-Series Data

```bash
# View latest JSONL entry
tail -1 container_vulnerability_metrics.jsonl | python3 -m json.tool

# View cluster-level entries only
grep '"aggregation.level": "cluster"' container_vulnerability_metrics.jsonl | python3 -m json.tool

# View specific cluster's history
jq 'select(.Attributes."cluster.name" == "AMS_EKS_Stage_01")' container_vulnerability_metrics.jsonl

# View trend over last 10 scans
tail -10 container_vulnerability_metrics.jsonl | jq '.Attributes.vulnerability.total'

# Extract vulnerability counts for graphing
jq -r '[.Timestamp, .Attributes."cluster.name", .Attributes."vulnerability.total"] | @csv' \
  container_vulnerability_metrics.jsonl > vulnerability_trend.csv
```

---

## Grafana Integration Setup

### Prerequisites

- Docker or native installation of:
  - **Grafana** (visualization platform)
  - **Loki** (log aggregation system)
  - **Promtail** (log shipper)

### Option 1: Docker Compose (Recommended)

Create `docker-compose.yml`:

```yaml
version: "3"

services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./loki-data:/loki

  promtail:
    image: grafana/promtail:latest
    volumes:
      - ./promtail-config.yaml:/etc/promtail/config.yml
      - ./container_vulnerability_metrics.jsonl:/var/log/vulnerabilities.jsonl:ro
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      - loki

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - loki

volumes:
  grafana-data:
```

Start the stack:

```bash
docker-compose up -d
```

### Option 2: Native Installation

#### Install Loki

```bash
# macOS (Homebrew)
brew install loki

# Linux
wget https://github.com/grafana/loki/releases/download/v2.9.0/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
chmod a+x loki-linux-amd64

# Start Loki
loki -config.file=/usr/local/etc/loki-local-config.yaml
```

#### Install Promtail

```bash
# macOS (Homebrew)
brew install promtail

# Linux
wget https://github.com/grafana/loki/releases/download/v2.9.0/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
chmod a+x promtail-linux-amd64
```

#### Install Grafana

```bash
# macOS (Homebrew)
brew install grafana

# Linux (Debian/Ubuntu)
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt-get update
sudo apt-get install grafana
```

### Configure Promtail

Create or update `config/promtail-config.yaml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: container_vulnerabilities
    static_configs:
      - targets:
          - localhost
        labels:
          job: trend-micro-container-security
          __path__: /absolute/path/to/Integration-API-Dev/container_vulnerability_metrics.jsonl
    
    pipeline_stages:
      # Parse JSON
      - json:
          expressions:
            timestamp: Timestamp
            environment: Resource.deployment.environment
            business_name: Resource.cloud.account.name
            business_id: Resource.cloud.account.id
            region: Resource.cloud.region
            group_id: Attributes.group.id
            group_name: Attributes.group.name
            cluster_id: Attributes.cluster.id
            cluster_name: Attributes.cluster.name
            aggregation_level: Attributes.aggregation.level
            vuln_total: Attributes.vulnerability.total
            vuln_critical: Attributes.vulnerability.severity.critical
            vuln_high: Attributes.vulnerability.severity.high
            vuln_medium: Attributes.vulnerability.severity.medium
            vuln_low: Attributes.vulnerability.severity.low
            risk_score: Attributes.vulnerability.risk_score
      
      # Add labels for filtering
      - labels:
          environment:
          business_name:
          region:
          group_name:
          cluster_name:
          aggregation_level:
      
      # Parse timestamp
      - timestamp:
          source: timestamp
          format: RFC3339
```

**Important:** Replace `/absolute/path/to/Integration-API-Dev/` with your actual path.

Start Promtail:

```bash
promtail -config.file=config/promtail-config.yaml
```

---

## Dashboard Configuration

### 1. Add Loki Data Source

1. Open Grafana: http://localhost:3000
2. Default credentials: `admin` / `admin`
3. Go to **Configuration → Data Sources**
4. Click **Add data source**
5. Select **Loki**
6. Configure:
   - **Name:** Loki
   - **URL:** `http://localhost:3100`
   - Click **Save & Test**

### 2. Import Pre-built Dashboard

A ready-to-use Grafana dashboard is provided in `config/grafana-dashboard-container-security.json`.

**Import Steps:**

1. Go to **Dashboards → Import**
2. Click **Upload JSON file**
3. Select `config/grafana-dashboard-container-security.json`
4. Select **Loki** as the data source
5. Click **Import**

The dashboard includes:
- Total vulnerabilities by cluster (time-series)
- Critical/High vulnerabilities trend
- Risk score trending
- Severity distribution
- Environment comparison
- Cluster comparison table

### 3. Create Custom Dashboard

#### Panel 1: Total Vulnerabilities Over Time

**Query (LogQL):**
```logql
{job="trend-micro-container-security", aggregation_level="cluster"} 
| json
| line_format "{{.Attributes.vulnerability.total}}"
```

**Visualization:** Time series  
**Legend:** `{{cluster_name}}`

#### Panel 2: Critical Vulnerabilities by Cluster

**Query (LogQL):**
```logql
sum by (cluster_name) (
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | unwrap Attributes.vulnerability.severity.critical [5m]
)
```

**Visualization:** Bar chart  
**Legend:** `{{cluster_name}}`

#### Panel 3: Risk Score Heatmap

**Query (LogQL):**
```logql
{job="trend-micro-container-security", aggregation_level="cluster"} 
| json
| unwrap Attributes.vulnerability.risk_score
```

**Visualization:** Heatmap

#### Panel 4: Severity Distribution

**Query (LogQL):**
```logql
sum(
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | unwrap Attributes.vulnerability.severity.critical
)
```

Repeat for high, medium, low

**Visualization:** Pie chart

#### Panel 5: Cluster Comparison Table

**Query (LogQL):**
```logql
{job="trend-micro-container-security", aggregation_level="cluster"} 
| json
```

**Visualization:** Table  
**Columns:** Cluster Name, Total, Critical, High, Medium, Low, Risk Score

---

## Query Examples

### LogQL Queries (Loki)

#### 1. Get Latest Vulnerability Count for Each Cluster

```logql
last_over_time(
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | unwrap Attributes.vulnerability.total [24h]
)
```

#### 2. Critical Vulnerabilities Trend (Last 7 Days)

```logql
{job="trend-micro-container-security", aggregation_level="cluster"} 
| json
| unwrap Attributes.vulnerability.severity.critical
```

Set time range to "Last 7 days"

#### 3. Clusters with Critical Vulnerabilities

```logql
{job="trend-micro-container-security", aggregation_level="cluster"} 
| json
| Attributes.vulnerability.severity.critical > 0
| line_format "{{.Attributes.cluster.name}}: {{.Attributes.vulnerability.severity.critical}} critical"
```

#### 4. Risk Score by Environment

```logql
sum by (environment) (
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | unwrap Attributes.vulnerability.risk_score
)
```

#### 5. Vulnerability Growth Rate

```logql
rate(
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | unwrap Attributes.vulnerability.total [1h]
)
```

#### 6. Filter by Specific Cluster

```logql
{job="trend-micro-container-security", cluster_name="AMS_EKS_Stage_01"} 
| json
```

#### 7. Multi-Environment Comparison

```logql
sum by (environment, cluster_name) (
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | unwrap Attributes.vulnerability.total
)
```

### JSON Queries (Direct File Access)

#### Extract Time-Series Data for Excel

```bash
jq -r '[.Timestamp, .Attributes."cluster.name", .Attributes."vulnerability.total", .Attributes."vulnerability.severity.critical", .Attributes."vulnerability.severity.high"] | @csv' \
  container_vulnerability_metrics.jsonl > grafana_import.csv
```

#### Get Latest Scan for All Clusters

```bash
jq -s 'group_by(.Attributes."cluster.name") | map(max_by(.Timestamp))' \
  container_vulnerability_metrics.jsonl | \
  jq '.[] | {cluster: .Attributes."cluster.name", total: .Attributes."vulnerability.total", critical: .Attributes."vulnerability.severity.critical"}'
```

#### Calculate Average Vulnerabilities Per Cluster

```bash
jq -s 'group_by(.Attributes."cluster.name") | map({cluster: .[0].Attributes."cluster.name", avg: (map(.Attributes."vulnerability.total") | add / length)})' \
  container_vulnerability_metrics.jsonl
```

---

## Alerting

### Configure Grafana Alerts

#### Alert 1: Critical Vulnerabilities Spike

**Condition:**
```logql
{job="trend-micro-container-security", aggregation_level="cluster"} 
| json
| unwrap Attributes.vulnerability.severity.critical
> 10
```

**Threshold:** 10 critical vulnerabilities  
**Evaluation:** Every 5 minutes  
**For:** 10 minutes  
**Action:** Send notification to Slack/Email

#### Alert 2: Risk Score Increase

**Condition:**
```logql
increase(
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | unwrap Attributes.vulnerability.risk_score [1h]
) > 100
```

**Threshold:** Risk score increases by 100 in 1 hour  
**Action:** Send notification to PagerDuty

#### Alert 3: New Critical CVE Detected

**Condition:**
```logql
changes(
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | Attributes.vulnerability.severity.critical [5m]
) > 0
```

**Threshold:** Any increase in critical vulnerabilities  
**Action:** Immediate notification

### Alert Notification Channels

Configure in **Alerting → Notification channels**:

- **Slack:** Send to `#security-alerts`
- **Email:** Send to security team
- **PagerDuty:** For critical incidents
- **Webhook:** Custom integrations (JIRA, ServiceNow)

---

## Best Practices

### 1. Scan Frequency

Choose scan frequency based on environment:

| Environment | Recommended Frequency | Rationale |
|------------|----------------------|-----------|
| Production | Every 6 hours | Balance between freshness and API load |
| Staging | Every 12 hours | Less critical, fewer scans needed |
| Development | Daily | Lower priority, reduce API calls |

More frequent scans = better trending, but consider API rate limits.

### 2. Data Retention

**Loki Configuration:**

```yaml
# loki-config.yaml
limits_config:
  retention_period: 90d  # Keep 90 days of data

table_manager:
  retention_deletes_enabled: true
  retention_period: 90d
```

**JSONL File Rotation:**

Create `rotate_jsonl.sh`:

```bash
#!/bin/bash
LOG_FILE="container_vulnerability_metrics.jsonl"
MAX_SIZE_MB=100

# Get file size in MB
FILE_SIZE=$(du -m "$LOG_FILE" | cut -f1)

if [ "$FILE_SIZE" -gt "$MAX_SIZE_MB" ]; then
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    mv "$LOG_FILE" "${LOG_FILE}.${TIMESTAMP}"
    gzip "${LOG_FILE}.${TIMESTAMP}"
    touch "$LOG_FILE"
    echo "Rotated log file at $TIMESTAMP"
fi
```

Add to crontab:
```bash
0 */6 * * * /path/to/rotate_jsonl.sh
```

### 3. Backup Strategy

```bash
#!/bin/bash
# backup_vulnerability_data.sh

BACKUP_DIR=~/backups/vulnerability-data
TIMESTAMP=$(date +%Y%m%d)

mkdir -p $BACKUP_DIR

# Backup all three formats
tar -czf $BACKUP_DIR/vulnerability-data-${TIMESTAMP}.tar.gz \
  container_vulnerability_summary.csv \
  container_vulnerability_report.txt \
  container_vulnerability_metrics.jsonl

# Keep only last 30 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/vulnerability-data-${TIMESTAMP}.tar.gz"
```

Schedule daily backups:
```bash
0 3 * * * /path/to/backup_vulnerability_data.sh
```

### 4. Performance Optimization

**Promtail:**
- Use `static_positions` for faster startup
- Enable compression for log shipping
- Set appropriate `batch_size`

**Loki:**
- Configure appropriate retention
- Enable query caching
- Use compaction for storage efficiency

**Grafana:**
- Set reasonable refresh intervals (1m minimum)
- Use query caching
- Limit dashboard panels to essential metrics

### 5. Monitoring the Monitor

Set up alerts for the monitoring system itself:

- **Promtail not shipping logs**
- **Loki storage full**
- **Grafana API errors**
- **JSONL file growth rate anomalies**

---

## Troubleshooting

### Issue 1: No Data in Grafana

**Symptoms:**
- Empty graphs
- "No data" message in panels

**Diagnosis:**

```bash
# 1. Check JSONL file exists and has data
ls -lh container_vulnerability_metrics.jsonl
tail -5 container_vulnerability_metrics.jsonl | python3 -m json.tool

# 2. Check Promtail is running
curl http://localhost:9080/ready

# 3. Check Promtail metrics
curl http://localhost:9080/metrics | grep promtail_sent_entries_total

# 4. Check Loki is receiving logs
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="trend-micro-container-security"}' \
  --data-urlencode 'limit=5' | jq

# 5. Check Loki labels
curl -s "http://localhost:3100/loki/api/v1/labels" | jq
```

**Solutions:**
- Verify Promtail `__path__` is absolute path
- Check file permissions: `chmod 644 container_vulnerability_metrics.jsonl`
- Restart Promtail: `docker-compose restart promtail`
- Check Promtail logs: `docker-compose logs promtail`

### Issue 2: Timestamps Not Parsing

**Symptoms:**
- Time-series graphs show wrong time
- Logs appear at wrong time in Grafana

**Diagnosis:**

```bash
# Check timestamp format (should be RFC3339)
tail -1 container_vulnerability_metrics.jsonl | jq '.Timestamp'
# Expected: "2026-01-20T21:26:24.726030Z"
```

**Solution:**
Verify Promtail `pipeline_stages` has correct timestamp config:

```yaml
- timestamp:
    source: timestamp
    format: RFC3339
```

### Issue 3: Missing Labels in Loki

**Symptoms:**
- Cannot filter by cluster_name, environment, etc.
- Label dropdown in Grafana is empty

**Diagnosis:**

```bash
# Check available labels
curl -s "http://localhost:3100/loki/api/v1/labels" | jq

# Check label values
curl -s "http://localhost:3100/loki/api/v1/label/cluster_name/values" | jq
```

**Solution:**
Verify Promtail `pipeline_stages` includes labels:

```yaml
- labels:
    environment:
    cluster_name:
    aggregation_level:
```

Restart Promtail after config changes.

### Issue 4: High Memory Usage (Loki)

**Symptoms:**
- Loki consuming excessive memory
- OOM kills

**Solution:**

Configure limits in `loki-config.yaml`:

```yaml
limits_config:
  # Limit query range
  max_query_length: 721h  # 30 days

  # Limit concurrent queries
  max_concurrent_tail_requests: 10
  
  # Limit ingestion rate
  ingestion_rate_mb: 4
  ingestion_burst_size_mb: 6
```

### Issue 5: JSONL File Growing Too Large

**Symptoms:**
- File exceeds 1GB
- Slow query performance

**Solution:**

Implement rotation (see Best Practices #2) or manually rotate:

```bash
# Rotate manually
mv container_vulnerability_metrics.jsonl container_vulnerability_metrics.jsonl.$(date +%Y%m%d)
gzip container_vulnerability_metrics.jsonl.*
touch container_vulnerability_metrics.jsonl

# Restart Promtail to pick up new file
docker-compose restart promtail
```

### Issue 6: Duplicate Data in Grafana

**Symptoms:**
- Same data appears multiple times
- Graphs show spikes

**Cause:** Promtail re-reading file from beginning

**Solution:**

Check Promtail positions:

```bash
cat /tmp/positions.yaml
```

If corrupted, stop Promtail, delete positions file, restart:

```bash
docker-compose stop promtail
rm /tmp/positions.yaml
docker-compose start promtail
```

---

## Advanced Topics

### Multi-Region Dashboards

Filter by region using variables:

1. Create dashboard variable:
   - Name: `region`
   - Type: Query
   - Query: `label_values(region)`

2. Use in queries:
   ```logql
   {job="trend-micro-container-security", region="$region"}
   ```

### Custom Metrics Export to Prometheus

Convert JSONL to Prometheus format:

```python
#!/usr/bin/env python3
# otel_to_prometheus.py
from prometheus_client import Gauge, CollectorRegistry, write_to_textfile
import json

registry = CollectorRegistry()

vuln_total = Gauge('container_vulnerability_total', 'Total vulnerabilities', 
                   ['cluster', 'environment'], registry=registry)
vuln_critical = Gauge('container_vulnerability_critical', 'Critical vulnerabilities',
                      ['cluster', 'environment'], registry=registry)
vuln_high = Gauge('container_vulnerability_high', 'High vulnerabilities',
                  ['cluster', 'environment'], registry=registry)
vuln_risk = Gauge('container_vulnerability_risk_score', 'Risk score',
                  ['cluster', 'environment'], registry=registry)

# Read latest entry per cluster
latest_data = {}
with open('container_vulnerability_metrics.jsonl') as f:
    for line in f:
        entry = json.loads(line)
        if entry.get('Attributes', {}).get('aggregation.level') != 'cluster':
            continue
        
        cluster = entry['Attributes']['cluster.name']
        env = entry['Resource']['deployment.environment']
        timestamp = entry['Timestamp']
        
        if cluster not in latest_data or timestamp > latest_data[cluster]['timestamp']:
            latest_data[cluster] = {
                'timestamp': timestamp,
                'env': env,
                'total': entry['Attributes']['vulnerability.total'],
                'critical': entry['Attributes']['vulnerability.severity.critical'],
                'high': entry['Attributes']['vulnerability.severity.high'],
                'risk': entry['Attributes']['vulnerability.risk_score']
            }

# Set metrics
for cluster, data in latest_data.items():
    vuln_total.labels(cluster=cluster, environment=data['env']).set(data['total'])
    vuln_critical.labels(cluster=cluster, environment=data['env']).set(data['critical'])
    vuln_high.labels(cluster=cluster, environment=data['env']).set(data['high'])
    vuln_risk.labels(cluster=cluster, environment=data['env']).set(data['risk'])

write_to_textfile('container_vulnerabilities.prom', registry)
print("Prometheus metrics written to container_vulnerabilities.prom")
```

Run after each scan:

```bash
python3 otel_to_prometheus.py
```

Configure Prometheus to scrape the file or use `node_exporter`'s textfile collector.

### Integration with Other Tools

#### Splunk

```bash
# Forward to Splunk HEC
while IFS= read -r line; do
    curl -k https://splunk:8088/services/collector/event \
      -H "Authorization: Splunk YOUR_HEC_TOKEN" \
      -d "$line"
done < container_vulnerability_metrics.jsonl
```

#### Elasticsearch

```bash
# Bulk import
cat container_vulnerability_metrics.jsonl | \
jq -c '. | {"index": {"_index": "vulnerabilities-" + (.Timestamp[:10])}}, .' | \
curl -XPOST 'localhost:9200/_bulk' \
  -H 'Content-Type: application/json' \
  --data-binary @-
```

#### Datadog

Configure Datadog Agent to tail the JSONL file:

```yaml
# /etc/datadog-agent/conf.d/vulnerabilities.d/conf.yaml
logs:
  - type: file
    path: /path/to/container_vulnerability_metrics.jsonl
    service: trend-micro-container-security
    source: json
    sourcecategory: vulnerabilities
```

---

## Resources

### Official Documentation

- [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)

### Grafana Dashboards

- [Public Dashboards](https://grafana.com/grafana/dashboards/)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/)

### Community

- [Grafana Community Forum](https://community.grafana.com/)
- [Loki GitHub](https://github.com/grafana/loki)

---

## Support

### Getting Help

1. **Check logs:**
   ```bash
   # Script logs
   python3 get_container_vulnerabilities.py 2>&1 | tee debug.log
   
   # Promtail logs
   docker-compose logs promtail
   
   # Loki logs
   docker-compose logs loki
   ```

2. **Verify configuration:**
   ```bash
   cat config/promtail-config.yaml
   cat config/environments.json
   ```

3. **Test connectivity:**
   ```bash
   # Test Loki
   curl http://localhost:3100/ready
   
   # Test Grafana
   curl http://localhost:3000/api/health
   ```

### Contact

- **Script Issues:** Open an issue in the repository
- **Trend Micro API:** https://automation.trendmicro.com/xdr/api-beta/
- **Grafana Support:** https://grafana.com/docs/

---

## Next Steps

1. ✅ **Run initial scan** to generate data
   ```bash
   python3 get_container_vulnerabilities.py
   ```

2. ✅ **Schedule automated scans** via cron
   ```bash
   crontab -e
   # Add: 0 */6 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet
   ```

3. ✅ **Set up Grafana stack**
   ```bash
   docker-compose up -d
   ```

4. ✅ **Import dashboard**
   - Open Grafana: http://localhost:3000
   - Import `config/grafana-dashboard-container-security.json`

5. ✅ **Configure alerts**
   - Set up notification channels
   - Create alert rules for critical vulnerabilities

6. ✅ **Monitor trends**
   - Review dashboards daily
   - Track vulnerability remediation progress

---

**Last Updated:** January 21, 2026  
**Document Version:** 4.0  
**Script Version:** 4.0
