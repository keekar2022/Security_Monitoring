# Grafana & Loki Setup Guide

**Version:** 4.0 | **Last Updated:** January 21, 2026 | **Time Required:** 10-20 minutes  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start (10 Minutes)](#quick-start-10-minutes)
4. [Detailed Setup](#detailed-setup)
5. [Dashboard Configuration](#dashboard-configuration)
6. [Query Examples](#query-examples)
7. [Alerting](#alerting)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Overview

This guide shows how to set up Grafana and Loki to visualize container vulnerability data from the `container_vulnerability_metrics.jsonl` file.

**What You Get:**
- ✅ Time-series vulnerability trending
- ✅ Interactive dashboards
- ✅ Cluster-level comparison
- ✅ Automated alerting
- ✅ Risk score tracking

**OpenTelemetry Format:** The script generates OTel-compliant JSONL logs that work seamlessly with Grafana/Loki.

---

## Prerequisites

- ✅ Docker and Docker Compose installed
- ✅ Container vulnerability data generated (`container_vulnerability_metrics.jsonl`)
- ✅ 2GB free disk space
- ✅ Ports 3000 (Grafana), 3100 (Loki) available

---

## Quick Start (10 Minutes)

### Step 1: Generate Initial Data (2 minutes)

```bash
cd /path/to/Integration-API-Dev

# Run first scan
python3 get_container_vulnerabilities.py

# Verify JSONL file created
ls -lh container_vulnerability_metrics.jsonl
```

### Step 2: Create Docker Compose File (2 minutes)

```bash
cat > docker-compose.yml << 'EOF'
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
      - ./config/promtail-config.yaml:/etc/promtail/config.yml:ro
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
EOF
```

### Step 3: Update Promtail Config (1 minute)

```bash
# Update promtail config with absolute path
CURRENT_DIR=$(pwd)
sed -i.bak "s|__path__:.*|__path__: ${CURRENT_DIR}/container_vulnerability_metrics.jsonl|" \
  config/promtail-config.yaml

# Verify
grep "__path__" config/promtail-config.yaml
```

### Step 4: Start Stack (2 minutes)

```bash
# Start services
docker-compose up -d

# Wait for startup
sleep 15

# Check status
docker-compose ps
```

### Step 5: Configure Grafana (3 minutes)

1. **Open Grafana:** http://localhost:3000
2. **Login:** admin / admin (skip password change for now)
3. **Add Loki data source:**
   - Configuration → Data Sources → Add data source
   - Select **Loki**
   - URL: `http://loki:3100`
   - Click **Save & Test**
4. **Import dashboard:**
   - Dashboards → Import
   - Upload: `config/grafana-dashboard-container-security.json`
   - Select Loki data source
   - Click **Import**

**Done!** 🎉 Your dashboard is ready.

---

## Detailed Setup

### Understanding the Data Flow

```
Vulnerability Scan
      ↓
container_vulnerability_metrics.jsonl (OpenTelemetry format)
      ↓
Promtail (reads JSONL file, ships to Loki)
      ↓
Loki (stores time-series logs)
      ↓
Grafana (queries Loki, displays dashboards)
```

### Promtail Configuration

The `config/promtail-config.yaml` file is pre-configured to:
- Read the JSONL file
- Parse JSON fields
- Extract labels for filtering
- Send to Loki

**Key sections:**
```yaml
scrape_configs:
  - job_name: container_vulnerabilities
    static_configs:
      - targets: [localhost]
        labels:
          job: trend-micro-container-security
          __path__: /absolute/path/to/container_vulnerability_metrics.jsonl
    
    pipeline_stages:
      - json:
          expressions:
            cluster_name: Attributes.cluster.name
            environment: Resource.deployment.environment
            vuln_total: Attributes.vulnerability.total
            vuln_critical: Attributes.vulnerability.severity.critical
            
      - labels:
          cluster_name:
          environment:
          
      - timestamp:
          source: timestamp
          format: RFC3339
```

### OpenTelemetry Log Format

Each JSONL entry follows the OTel Logs Data Model:

```json
{
  "Timestamp": "2026-01-21T12:00:00.000000Z",
  "Body": "Container Security vulnerability scan for cluster 'AMS_EKS_Stage_01'",
  "Resource": {
    "deployment.environment": "Production",
    "cloud.account.name": "Adobe-AMS-Global",
    "cloud.region": "us"
  },
  "Attributes": {
    "cluster.id": "AMS_EKS_Stage_01-xyz",
    "cluster.name": "AMS_EKS_Stage_01",
    "vulnerability.total": 403,
    "vulnerability.severity.critical": 9,
    "vulnerability.severity.high": 102,
    "vulnerability.risk_score": 1022,
    "aggregation.level": "cluster"
  }
}
```

---

## Dashboard Configuration

### Pre-built Dashboard

The provided dashboard includes:

1. **Total Vulnerabilities Over Time** - Line graph per cluster
2. **Critical Vulnerabilities** - Bar chart
3. **Risk Score Heatmap** - Visual risk assessment
4. **Severity Distribution** - Pie chart
5. **Environment Comparison** - Multi-environment view
6. **Cluster Details Table** - Sortable data table

### Creating Custom Panels

**Example 1: Total Vulnerabilities by Cluster**

```logql
{job="trend-micro-container-security", aggregation_level="cluster"} 
| json
| unwrap Attributes.vulnerability.total
```

**Visualization:** Time series  
**Legend:** `{{cluster_name}}`

**Example 2: Critical Vulnerabilities Only**

```logql
{job="trend-micro-container-security"} 
| json
| Attributes.vulnerability.severity.critical > 0
| line_format "{{.Attributes.cluster.name}}: {{.Attributes.vulnerability.severity.critical}} critical"
```

---

## Query Examples

### LogQL Basics

```logql
# Get all vulnerability data
{job="trend-micro-container-security"}

# Filter by cluster
{cluster_name="AMS_EKS_Stage_01"}

# Filter by environment
{environment="Production"}

# Parse JSON and extract field
{job="trend-micro-container-security"} 
| json
| line_format "{{.Attributes.vulnerability.total}}"
```

### Advanced Queries

**Latest vulnerability count per cluster:**
```logql
last_over_time(
  {job="trend-micro-container-security", aggregation_level="cluster"} 
  | json
  | unwrap Attributes.vulnerability.total [24h]
)
```

**Clusters with increasing vulnerabilities:**
```logql
rate(
  {job="trend-micro-container-security"} 
  | json
  | unwrap Attributes.vulnerability.total [1h]
) > 0
```

**Risk score by environment:**
```logql
sum by (environment) (
  {job="trend-micro-container-security"} 
  | json
  | unwrap Attributes.vulnerability.risk_score
)
```

---

## Alerting

### Alert Example 1: Critical Vulnerabilities

**Condition:**
```logql
{job="trend-micro-container-security"} 
| json
| unwrap Attributes.vulnerability.severity.critical
> 10
```

**Settings:**
- Threshold: 10 critical vulnerabilities
- Evaluation: Every 5 minutes
- For: 10 minutes
- Action: Send to Slack/Email

### Alert Example 2: Risk Score Spike

**Condition:**
```logql
increase(
  {job="trend-micro-container-security"} 
  | json
  | unwrap Attributes.vulnerability.risk_score [1h]
) > 100
```

**Settings:**
- Threshold: Risk score increases by 100 in 1 hour
- Action: PagerDuty notification

### Configure Notifications

1. Go to **Alerting** → **Notification channels**
2. Add channel (Slack, Email, PagerDuty, etc.)
3. Create alert rules in dashboard panels
4. Test notifications

---

## Best Practices

### Scan Frequency

| Environment | Frequency | Rationale |
|------------|-----------|-----------|
| Production | Every 6 hours | Balance freshness vs API load |
| Staging | Every 12 hours | Less critical |
| Development | Daily | Lowest priority |

```bash
# Add to crontab
0 */6 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --environment production --quiet
```

### Data Retention

Configure in `docker-compose.yml`:

```yaml
loki:
  command: -config.file=/etc/loki/local-config.yaml -limits.retention-period=90d
```

### File Rotation

```bash
# Rotate JSONL file when it exceeds 100MB
if [ $(stat -f%z container_vulnerability_metrics.jsonl) -gt 104857600 ]; then
    mv container_vulnerability_metrics.jsonl \
       container_vulnerability_metrics.jsonl.$(date +%Y%m%d)
    gzip container_vulnerability_metrics.jsonl.*
    touch container_vulnerability_metrics.jsonl
fi
```

---

## Troubleshooting

### Issue 1: No Data in Grafana

**Check 1:** JSONL file exists
```bash
ls -lh container_vulnerability_metrics.jsonl
tail -1 container_vulnerability_metrics.jsonl | python3 -m json.tool
```

**Check 2:** Promtail is shipping
```bash
docker-compose logs promtail | grep "clients/client"
```

**Check 3:** Loki is receiving
```bash
curl -s "http://localhost:3100/loki/api/v1/labels" | python3 -m json.tool
```

**Solution:** Restart Promtail
```bash
docker-compose restart promtail
```

### Issue 2: Grafana Not Loading

```bash
# Check logs
docker-compose logs grafana

# Restart
docker-compose restart grafana

# Verify access
curl http://localhost:3000/api/health
```

### Issue 3: Wrong Timestamps

**Verify timestamp format:**
```bash
tail -1 container_vulnerability_metrics.jsonl | jq '.Timestamp'
# Should be: "2026-01-21T12:34:56.789012Z"
```

**Solution:** Ensure Promtail pipeline has correct timestamp format:
```yaml
- timestamp:
    source: timestamp
    format: RFC3339
```

---

## Commands Reference

```bash
# DOCKER COMPOSE
docker-compose up -d              # Start services
docker-compose ps                 # Check status
docker-compose logs -f loki       # View Loki logs
docker-compose logs -f promtail   # View Promtail logs
docker-compose restart promtail   # Restart Promtail
docker-compose down               # Stop services
docker-compose down -v            # Stop and remove volumes

# VERIFICATION
curl http://localhost:3100/ready                    # Check Loki
curl http://localhost:3000/api/health               # Check Grafana
curl http://localhost:9080/ready                    # Check Promtail

# QUERY LOKI DIRECTLY
curl -G "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="trend-micro-container-security"}' \
  --data-urlencode 'limit=5' | jq

# VIEW DATA
tail -f container_vulnerability_metrics.jsonl | jq
grep '"aggregation.level": "cluster"' container_vulnerability_metrics.jsonl | wc -l
```

---

## Resources

- **Grafana Documentation:** https://grafana.com/docs/
- **Loki Documentation:** https://grafana.com/docs/loki/
- **LogQL Query Language:** https://grafana.com/docs/loki/latest/logql/
- **OpenTelemetry Specification:** https://opentelemetry.io/docs/specs/otel/

---

**Last Updated:** January 21, 2026 | **Version:** 4.0
