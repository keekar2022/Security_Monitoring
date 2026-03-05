# System Health Monitoring Guide

**Author:** Mukesh Kesharwani (mkesharw@adobe.com)  
**Version:** 1.0.0  
**Last Updated:** February 5, 2026

---

## Overview

This guide explains how to monitor AWS account systems, agent installations, agent versions, and system health using the Trend Micro Vision One XDR API integration.

## Quick Answer to Your Questions

| Your Question | Answer | Data Source |
|--------------|--------|-------------|
| **1. Total systems in every AWS account** | ✅ **YES** - Available | Cloud Risk Management API |
| **2. Systems with Deep Security Agents** | ⚠️ **PARTIAL** - Vision One agents only | OAT Detections API |
| **3. Systems with 3+ month old agents** | ✅ **YES** - Detectable | Agent version timestamps |
| **4. Healthy systems count** | ✅ **YES** - Calculated | Activity & version analysis |

---

## Available Tools

### 1. AWS Account Statistics

**Tool:** `get_aws_account_stats`

**Purpose:** Discover AWS accounts connected to Trend Vision One and count resources per account.

```bash
# Scan all environments
./go/bin/get_aws_account_stats

# Scan specific environment
./go/bin/get_aws_account_stats --environment quality_test

# Get summary only (no files)
./go/bin/get_aws_account_stats --summary-only

# Filter by provider
./go/bin/get_aws_account_stats --provider aws
```

**Output:**
- `aws_account_report.txt` - Human-readable report
- `aws_account_summary.csv` - Excel/database ready
- `aws_account_metrics.jsonl` - Grafana/Loki integration

**Sample Output:**
```
AWS Accounts:            2
Total Resources:         2244

By Cloud Provider:
  AWS            2 accounts

Account Details:
  AWS        ams-ssa-govcanada-stage       851725363327      1010 2026-02-04
  AWS        ams-bpbu1590-aemgovau-stage   928475551084      1234 2026-02-04
```

### 2. Comprehensive System Health Report

**Tool:** `get_system_health_report`

**Purpose:** Answers ALL 4 of your questions in one comprehensive report.

```bash
# Full analysis
./go/bin/get_system_health_report --environment quality_test

# Summary only
./go/bin/get_system_health_report --summary-only

# Custom agent age threshold (default: 90 days)
./go/bin/get_system_health_report --age-days 60

# All environments
./go/bin/get_system_health_report
```

**Output:**
- `system_health_report.txt` - Comprehensive text report
- `system_health_summary.csv` - Summary statistics
- `system_health_metrics.jsonl` - Time-series metrics

**Sample Output:**
```
📊 ANSWERS TO YOUR QUESTIONS:

1. Total Systems in AWS Accounts:          6 systems across 2 AWS accounts
2. Systems with Agents Installed:          6 systems (100.0%)
3. Systems with 90+ Day Old Agents:        6 systems (100.0%)
4. Healthy Systems:                        0 systems (0.0%)
```

---

## Understanding the Data

### Question 1: Total Systems in AWS Accounts

**Data Source:** `/v3.0/cloudRiskManagement/accounts` API

**What It Provides:**
- List of AWS accounts connected to Vision One
- AWS Account ID (e.g., `851725363327`)
- Account name/label
- Total resource count per account
- Last monitoring timestamps

**Limitations:**
- Only shows AWS accounts **connected to Vision One**
- Resource count includes ALL AWS resources (EC2, Lambda, S3, etc.), not just compute instances
- Does not distinguish between EC2 instances and other resource types

**Example Data:**
```json
{
  "id": "53ff3ab4-0b43-42a9-8120-ce2799995ed9",
  "name": "ams-ssa-govcanada-stage",
  "provider": "aws",
  "awsAccountId": "851725363327",
  "resourceCount": 1010,
  "lastCheckedDateTime": "2026-02-04T18:33:45Z"
}
```

### Question 2: Systems with Deep Security Agents

**Current Answer:** ⚠️ **PARTIAL - Vision One Agents Only**

**Why Partial:**
- **Deep Security** and **Vision One XDR** are separate Trend Micro products
- Deep Security Manager API is separate: `automation.deepsecurity.trendmicro.com`
- Your integration currently only connects to Vision One XDR API
- No Deep Security Manager credentials found in configuration

**What IS Available:**
- Vision One endpoint sensors/agents
- Container security agents (detected via OAT API)
- Endpoint activity data from Vision One protected systems

**What Is NOT Available:**
- Deep Security Agent (DSA) inventory
- Deep Security module status (anti-malware, firewall, IPS, etc.)
- Deep Security-specific agent versions

**To Get Deep Security Agent Data:**

You would need to:
1. **Verify Deep Security Manager is deployed** in your environment
2. **Obtain Deep Security API credentials**
3. **Add Deep Security API integration** using endpoints like:
   - `/api/computers` - List all computers with agents
   - `/api/computers/{id}` - Get specific computer details
   - `/api/awsconnectors` - Get AWS account connections

**Workaround for Current Setup:**

Use the Vision One data as a proxy:
- Systems with **recent OAT detections** = Systems with Vision One sensors
- Vision One sensor ≈ "Trend Micro protection installed"
- Product name in data indicates agent type (e.g., "Vision One Container Security")

### Question 3: Systems with 3+ Month Old Agents

**Answer:** ✅ **YES - Available**

**Data Source:** OAT Detections API (`/v3.0/oat/detections`)

**How It Works:**
1. Extract agent version date from `pver` field
2. Calculate days since version date
3. Flag agents older than threshold (default: 90 days)

**Example Detection:**
```json
{
  "detail": {
    "pname": "Vision One Container Security",
    "pver": "2021-12-01T00:00:00.0000000Z",
    "osName": "Linux"
  }
}
```

**Calculation:**
```
Agent Age = Current Date - pver Date
Is Old Agent = Agent Age > 90 days
```

**Configurable Threshold:**
```bash
# Check for 60-day old agents
./go/bin/get_system_health_report --age-days 60

# Check for 180-day old agents
./go/bin/get_system_health_report --age-days 180
```

### Question 4: Healthy Systems Count

**Answer:** ✅ **YES - Calculated**

**Health Criteria:**

A system is considered **healthy** if ALL of the following are true:
1. ✅ Agent/sensor is installed (has detection data)
2. ✅ Last seen within 7 days (recent activity)
3. ✅ Agent version is less than 90 days old (configurable)

**Health Status Logic:**
```
IF last_seen_date < 7 days ago
AND agent_version_date < 90 days ago (default)
THEN status = HEALTHY
ELSE status = UNHEALTHY
```

**Unhealthy Indicators:**
- ⚠️ Agent version is 90+ days old
- ⚠️ No activity in past 7 days
- ❌ No agent data available

---

## Data Sources & APIs

### Available APIs

| API Endpoint | Purpose | Permission Required |
|--------------|---------|---------------------|
| `/v3.0/cloudRiskManagement/accounts` | AWS account list | Cloud Risk Management → View |
| `/v3.0/oat/detections` | Endpoint activity data | OAT Detections → View |
| `/v3.0/eiqs/endpoints` | Endpoint inventory | Endpoint Inventory → View |

### API Permissions

**Currently Working:**
- ✅ Container Security API
- ✅ Cloud Risk Management API
- ✅ OAT Detections API (partial - first 50 records)

**Limited/Not Working:**
- ⚠️ Endpoint Inventory API - Returns errors (may need additional permissions)
- ❌ Deep Security API - Not integrated

**To Enable Full Functionality:**

Update API role permissions in Trend Vision One console:
1. Navigate to: **Administration → User Roles → API Keys**
2. Add permissions:
   - ✅ **Cloud Risk Management** → View
   - ✅ **Observed Attack Techniques (OAT)** → View
   - ✅ **Endpoint Inventory** → View

---

## Automation & Scheduling

### Daily Health Check

```bash
#!/bin/bash
# daily_health_check.sh

cd /Users/mkesharw/Documents/Integration-API-Dev

# Run system health report
./go/bin/get_system_health_report \
    --environment production \
    --quiet

# Send alert if unhealthy systems found
UNHEALTHY=$(tail -1 system_health_summary.csv | cut -d',' -f8)
if [ "$UNHEALTHY" -lt 10 ]; then
    echo "WARNING: Only $UNHEALTHY healthy systems found" | \
        mail -s "System Health Alert" ops-team@company.com
fi
```

### Cron Job Setup

```bash
# Edit crontab
crontab -e

# Daily at 2 AM
0 2 * * * /path/to/daily_health_check.sh

# Weekly full report (all environments)
0 8 * * 1 cd /path/to/Integration-API-Dev && ./go/bin/get_system_health_report
```

### Systemd Timer

```ini
# /etc/systemd/system/system-health-check.service
[Unit]
Description=Trend Micro System Health Check
After=network.target

[Service]
Type=oneshot
User=mkesharw
WorkingDirectory=/Users/mkesharw/Documents/Integration-API-Dev
ExecStart=/Users/mkesharw/Documents/Integration-API-Dev/go/bin/get_system_health_report --quiet

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/system-health-check.timer
[Unit]
Description=Daily System Health Check
Requires=system-health-check.service

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Enable:**
```bash
sudo systemctl enable system-health-check.timer
sudo systemctl start system-health-check.timer
```

---

## Grafana Integration

### Promtail Configuration

Add to `config/promtail-config.yaml`:

```yaml
scrape_configs:
  - job_name: system_health
    static_configs:
      - targets:
          - localhost
        labels:
          job: trend_micro_system_health
          __path__: /path/to/system_health_metrics.jsonl
    pipeline_stages:
      - json:
          expressions:
            timestamp: Timestamp
            environment: deployment.environment
            total_systems: systems.total
            systems_with_agents: systems.with_agents
            old_agents: systems.old_agents
            healthy_systems: systems.healthy
            aws_accounts: aws.accounts.count
      - timestamp:
          source: timestamp
          format: RFC3339
          
  - job_name: aws_accounts
    static_configs:
      - targets:
          - localhost
        labels:
          job: trend_micro_aws_accounts
          __path__: /path/to/aws_account_metrics.jsonl
    pipeline_stages:
      - json:
          expressions:
            timestamp: Timestamp
            environment: deployment.environment
            account_name: cloud.account.name
            provider: cloud.provider
            resource_count: cloud.resource.count
      - timestamp:
          source: timestamp
          format: RFC3339
```

### LogQL Queries

```logql
# Total healthy systems by environment
sum by (deployment_environment) ({job="trend_micro_system_health"} | json | unwrap systems_healthy)

# AWS accounts with most resources
topk(10, sum by (cloud_account_name) ({job="trend_micro_aws_accounts"} | json | unwrap cloud_resource_count))

# Systems with old agents percentage
100 * sum({job="trend_micro_system_health"} | json | unwrap systems_old_agents) / 
sum({job="trend_micro_system_health"} | json | unwrap systems_total)

# Alert: Less than 80% healthy systems
sum({job="trend_micro_system_health"} | json | unwrap systems_healthy) / 
sum({job="trend_micro_system_health"} | json | unwrap systems_total) < 0.8
```

### Grafana Dashboard Panels

**1. System Health Overview**
```
Query: {job="trend_micro_system_health"} | json
Type: Stat Panel
Fields: systems.total, systems.healthy, systems.with_agents
```

**2. Health Trend Over Time**
```
Query: sum(systems_healthy) by (deployment_environment)
Type: Time Series
```

**3. AWS Accounts Table**
```
Query: {job="trend_micro_aws_accounts"} | json
Type: Table
Columns: account_name, provider, aws_account_id, resource_count
```

---

## Troubleshooting

### No AWS Accounts Found

**Symptom:**
```
⚠️  HTTP 404 (AWS accounts may not be configured)
AWS Accounts:            0
```

**Possible Causes:**
1. No AWS accounts connected to Vision One
2. API permission insufficient
3. Using wrong environment

**Solutions:**
1. Check Vision One console: **Service Management → Cloud Accounts → AWS**
2. Verify API token has "Cloud Risk Management → View" permission
3. Run: `./verify_pass_tokens.sh` to check credentials

### No Systems Detected

**Symptom:**
```
Total Systems:           0
```

**Possible Causes:**
1. No OAT detections in time window
2. No Trend Micro agents installed
3. API permission issues

**Solutions:**
1. Check Vision One console for recent detections
2. Verify endpoints are enrolled in Vision One
3. Test API: `curl -H "Authorization: Bearer $TOKEN" https://api.au.xdr.trendmicro.com/v3.0/oat/detections?top=5`

### All Agents Shown as Old

**Symptom:**
```
Old Agents (90+ days):   6 (100.0%)
Healthy Systems:         0 (0.0%)
```

**Explanation:**
- Agent version timestamps (`pver`) may represent product release date, not installation date
- Container agents may report static version dates

**Solutions:**
1. Adjust threshold: `--age-days 180` or `--age-days 365`
2. Focus on "Last Seen" dates instead of version dates
3. Contact Trend Micro support about accurate agent version tracking

### Permission Errors

**Symptom:**
```
❌ HTTP 403 Forbidden
❌ HTTP 400 Bad Request
```

**Solutions:**

Update API role permissions:
1. Log into Vision One console
2. Go to **Administration → User Roles → API Keys**
3. Find your API key and add permissions:
   - Cloud Risk Management → View
   - OAT Detections → View
   - Endpoint Inventory → View
4. Wait 5-15 minutes for permissions to propagate
5. Regenerate token if needed

---

## Comparison with Deep Security

| Feature | Vision One (Current) | Deep Security (Not Integrated) |
|---------|---------------------|--------------------------------|
| **API Base URL** | `api.xdr.trendmicro.com` | `automation.deepsecurity.trendmicro.com` |
| **Agent Type** | Vision One Endpoint Sensor | Deep Security Agent (DSA) |
| **AWS Integration** | Cloud Risk Management API | AWS Connectors API |
| **Modules** | XDR capabilities | Anti-malware, Firewall, IPS, IM, LI, AC |
| **System Inventory** | Via OAT Detections | Via Computers API |
| **Agent Status** | Activity-based | Direct agent status |
| **Integration Status** | ✅ Implemented | ❌ Not Implemented |

**To Add Deep Security Integration:**

1. Verify Deep Security Manager is accessible
2. Obtain Deep Security API key
3. Store credentials: `pass insert TrendMicro/deep_security/api_key`
4. Create new tool: `get_deep_security_agents.go`
5. Use endpoints:
   - `/api/computers` - List computers
   - `/api/computers/{id}` - Get computer details
   - `/api/awsconnectors` - AWS account integration

---

## Summary of Capabilities

### ✅ What You CAN Get

1. **AWS Account Information**
   - Account count
   - AWS Account IDs
   - Resource counts per account
   - Last monitoring timestamps

2. **System/Endpoint Inventory**
   - Systems with Vision One agents/sensors
   - Agent version information
   - Operating system details
   - Activity timestamps

3. **Agent Age Analysis**
   - Identify agents older than threshold
   - Calculate days since version release
   - Track agent version dates

4. **Health Status**
   - Calculated health based on activity + version
   - Identify systems needing attention
   - Track healthy system percentage

### ⚠️ What You Get PARTIALLY

1. **Total Systems**
   - Can get **resource count** from Cloud Risk Management
   - Cannot distinguish EC2 instances from other AWS resources
   - Only counts systems **with Vision One activity**

2. **Agent Installation**
   - Can detect **Vision One agents**
   - Cannot detect **Deep Security agents** (need Deep Security API)
   - May miss systems with no recent activity

### ❌ What You CANNOT Get (Without Additional Integration)

1. **Deep Security Agent Details**
   - Requires Deep Security Manager API integration
   - Need separate authentication

2. **Complete EC2 Instance List**
   - Would need direct AWS API integration
   - Currently limited to Vision One monitored resources

3. **Agent Installation Date**
   - Only have version release date
   - True installation date not available in current data

---

## Next Steps

### Immediate Actions

1. **Test the Tools**
   ```bash
   # Test AWS account discovery
   ./go/bin/get_aws_account_stats --environment quality_test
   
   # Test comprehensive health report
   ./go/bin/get_system_health_report --environment quality_test
   ```

2. **Review Permissions**
   - Check Vision One API role has required permissions
   - Test all environments (quality_test, production, production_au)

3. **Setup Automation**
   - Add cron job for daily reports
   - Configure alerts for unhealthy systems

### Future Enhancements

1. **Add Deep Security Integration**
   - If Deep Security Manager is available
   - Get complete agent inventory

2. **Add AWS Direct Integration**
   - Use AWS EC2 API to get complete instance list
   - Cross-reference with Vision One data

3. **Enhanced Health Metrics**
   - Add more health criteria
   - Include vulnerability data
   - Track compliance status

---

## Support

**Internal Contact:**
- **Author**: Mukesh Kesharwani
- **Email**: mkesharw@adobe.com

**Documentation:**
- [Main README](../README.md)
- [Configuration Guide](CONFIGURATION.md)
- [API Endpoints](../config/api_endpoints.json)

**Trend Micro Resources:**
- Vision One Portal: [portal.au.xdr.trendmicro.com](https://portal.au.xdr.trendmicro.com/)
- API Documentation: [automation.trendmicro.com/xdr/api-v3](https://automation.trendmicro.com/xdr/api-v3/)

---

**Last Updated:** February 5, 2026 | **Version:** 1.0.0
