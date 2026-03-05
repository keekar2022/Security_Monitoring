# Quick Start: System Health Monitoring

**5-Minute Guide to Get AWS Account and System Health Statistics**

---

## TL;DR - Run This Now

```bash
cd /Users/mkesharw/Documents/Integration-API-Dev

# Get comprehensive system health report for all environments
./go/bin/get_system_health_report
```

**Output:** Answers all 4 questions in one report!

---

## Your Questions - Quick Answers

Run this command to get instant answers:

```bash
./go/bin/get_system_health_report --summary-only
```

**Example Output:**
```
📊 ANSWERS TO YOUR QUESTIONS:

1. Total Systems in AWS Accounts:          10 systems across 3 AWS accounts
2. Systems with Agents Installed:          10 systems (100.0%)
3. Systems with 90+ Day Old Agents:        6 systems (60.0%)
4. Healthy Systems:                        4 systems (40.0%)
```

---

## Available Commands

### Command 1: AWS Account Statistics Only

```bash
# Quick summary
./go/bin/get_aws_account_stats --summary-only

# Full report with output files
./go/bin/get_aws_account_stats --environment quality_test
```

**What You Get:**
- AWS account count
- AWS Account IDs
- Resources per account
- Monitoring status

### Command 2: Comprehensive System Health Report

```bash
# Quick summary (recommended)
./go/bin/get_system_health_report --summary-only

# Full report with files
./go/bin/get_system_health_report

# Specific environment only
./go/bin/get_system_health_report --environment production_au

# Custom agent age threshold (default: 90 days)
./go/bin/get_system_health_report --age-days 60
```

**What You Get:**
- AWS accounts monitored
- Total systems found
- Systems with agents
- Systems with old agents
- Healthy systems count

---

## Output Files

When you run without `--summary-only`, you get:

### From AWS Account Stats:
- `aws_account_report.txt` - Human-readable
- `aws_account_summary.csv` - For Excel
- `aws_account_metrics.jsonl` - For Grafana/Loki

### From System Health Report:
- `system_health_report.txt` - Detailed report
- `system_health_summary.csv` - Summary stats
- `system_health_metrics.jsonl` - Time-series data

---

## Common Use Cases

### Use Case 1: Daily Health Check

```bash
#!/bin/bash
# daily_check.sh

cd /Users/mkesharw/Documents/Integration-API-Dev
./go/bin/get_system_health_report --quiet

# Email if unhealthy systems found
HEALTHY=$(tail -1 system_health_summary.csv | cut -d',' -f8)
if [ "$HEALTHY" -lt 5 ]; then
    echo "Only $HEALTHY healthy systems!" | mail -s "Alert" ops@company.com
fi
```

### Use Case 2: Weekly Executive Report

```bash
# Run full report and email results
./go/bin/get_system_health_report
cat system_health_report.txt | mail -s "Weekly System Health" exec@company.com
```

### Use Case 3: Check Specific Environment

```bash
# Before deployment - check production health
./go/bin/get_system_health_report --environment production --summary-only
```

### Use Case 4: Find Systems Needing Updates

```bash
# Check for systems with 60+ day old agents
./go/bin/get_system_health_report --age-days 60 --summary-only
```

---

## Understanding the Results

### Health Status Meaning

**Healthy System (✅):**
- Has agent installed
- Seen in last 7 days
- Agent version < 90 days old

**Unhealthy System (❌):**
- No recent activity (>7 days), OR
- Agent version > 90 days old, OR
- Missing agent data

### What "Old Agent" Means

- Default threshold: 90 days
- Measured from agent version date (`pver` field)
- May represent version release date, not installation date
- Adjust with `--age-days` flag if needed

### AWS Account vs. Systems

**AWS Accounts:**
- From Cloud Risk Management API
- Shows connected AWS accounts
- Includes resource count (all AWS resources)

**Systems:**
- From OAT Detections API
- Shows systems with Vision One agents
- Based on recent security activity

---

## Limitations to Know

### 1. Deep Security Agents

⚠️ **Currently shows Vision One agents only**

- Deep Security is a separate product with separate API
- To get Deep Security agent data, need Deep Security Manager integration
- Current tools show "Trend Micro protection" broadly

### 2. Resource Count vs. EC2 Instances

⚠️ **Resource count includes all AWS resources**

- Not just EC2 instances
- Includes Lambda, S3, RDS, etc.
- Use "Systems with Agents" for actual protected systems

### 3. Agent Version Date

⚠️ **May show product release date, not installation date**

- Container agents often report static dates
- Adjust `--age-days` threshold as needed
- Focus on "Last Seen" for activity

---

## Automation Setup

### Add to Crontab

```bash
# Edit crontab
crontab -e

# Add this line for daily 2 AM execution
0 2 * * * cd /Users/mkesharw/Documents/Integration-API-Dev && ./go/bin/get_system_health_report --quiet
```

### Systemd Timer

```bash
# Create service file
sudo cat > /etc/systemd/system/system-health.service <<EOF
[Unit]
Description=System Health Check

[Service]
Type=oneshot
User=$USER
WorkingDirectory=/Users/mkesharw/Documents/Integration-API-Dev
ExecStart=/Users/mkesharw/Documents/Integration-API-Dev/go/bin/get_system_health_report --quiet
EOF

# Create timer file
sudo cat > /etc/systemd/system/system-health.timer <<EOF
[Unit]
Description=Daily System Health Check

[Timer]
OnCalendar=daily
OnCalendar=02:00

[Install]
WantedBy=timers.target
EOF

# Enable and start
sudo systemctl enable system-health.timer
sudo systemctl start system-health.timer
```

---

## Troubleshooting

### No AWS Accounts Found

```bash
# Check credentials
./verify_pass_tokens.sh

# Test API access
TOKEN=$(pass show TrendMicro/quality_test/api_token)
curl -H "Authorization: Bearer $TOKEN" \
     "https://api.au.xdr.trendmicro.com/v3.0/cloudRiskManagement/accounts"
```

### No Systems Found

Possible reasons:
- No recent OAT detections (no activity in time window)
- No Vision One agents installed
- API permission issues

### All Agents Show as "Old"

- Container agents may report static version dates
- Adjust threshold: `--age-days 180` or `--age-days 365`
- Focus on "Last Seen" dates instead

---

## Need More Info?

**Full Documentation:**
- [System Health Monitoring Guide](SYSTEM_HEALTH_MONITORING.md)
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md)
- [Main README](../README.md)

**Quick Help:**
```bash
./go/bin/get_system_health_report --help
./go/bin/get_aws_account_stats --help
```

**Contact:**
- Mukesh Kesharwani (mkesharw@adobe.com)

---

## Example Session

```bash
# Navigate to project
cd /Users/mkesharw/Documents/Integration-API-Dev

# Run health report
./go/bin/get_system_health_report --summary-only

# Output:
# 🔍 System Health Analysis
#    Scanning environments: production_au, quality_test, production
#    Agent age threshold: 90 days
#
# ╔═══════════════════════════════════════════╗
# ║  ENVIRONMENT: PRODUCTION_AU               ║
# ╚═══════════════════════════════════════════╝
#
#   📊 SUMMARY FOR PRODUCTION_AU
#   AWS Accounts:            1
#   Total Systems:           3
#   With Agents:             3 (100.0%)
#   Old Agents (90+ days):   0 (0.0%)
#   Healthy Systems:         3 (100.0%)
#
# ... (repeat for other environments)
#
# ════════════════════════════════════════════
# OVERALL SUMMARY - ALL ENVIRONMENTS
# ════════════════════════════════════════════
#
# 📊 ANSWERS TO YOUR QUESTIONS:
#
# 1. Total Systems in AWS Accounts:     10 systems across 3 AWS accounts
# 2. Systems with Agents Installed:     10 systems (100.0%)
# 3. Systems with 90+ Day Old Agents:   6 systems (60.0%)
# 4. Healthy Systems:                   4 systems (40.0%)

# View detailed report
cat system_health_report.txt

# Open CSV in Excel
open system_health_summary.csv
```

---

**Last Updated:** February 5, 2026  
**Status:** ✅ Ready for Production Use
