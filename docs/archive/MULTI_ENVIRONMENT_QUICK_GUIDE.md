# Multi-Environment Scanning - Quick Guide

## Overview
The `get_container_vulnerabilities.py` script now supports scanning multiple Trend Micro Vision One environments (QTE, Production, Staging, Development) in a single run.

## Quick Commands

### Scan All Environments (Default)
```bash
python3 get_container_vulnerabilities.py
```
Automatically scans all environments with configured credentials.

### Scan Specific Environment
```bash
# Quality & Test environment
python3 get_container_vulnerabilities.py -e quality_test

# Production environment
python3 get_container_vulnerabilities.py -e production
```

### Scan Multiple Specific Environments
```bash
python3 get_container_vulnerabilities.py -e quality_test -e production
```

### Specific Group in Specific Environment
```bash
# By group name
python3 get_container_vulnerabilities.py -e production -n "Group_Name"

# By group ID
python3 get_container_vulnerabilities.py -e quality_test -g "group-id-here"
```

### Specific Group Across All Environments
```bash
python3 get_container_vulnerabilities.py --group-name "AMS_Zubin_Stage"
```
Searches for this group in all configured environments.

## Output Format

Results are grouped by environment with subtotals:

```
╔══════════════════════════════════════════════════════════════════════╗
║  CONTAINER SECURITY VULNERABILITY SUMMARY - ALL ENVIRONMENTS         ║
╚══════════════════════════════════════════════════════════════════════╝

┌────────────────────────────────────────────────────────────────────┐
│ 🌍 ENVIRONMENT: Quality & Test                                     │
│    Business: Adobe Managed Services QTE                            │
│    Region: Australia (au)                                          │
└────────────────────────────────────────────────────────────────────┘

Group Name                  Clusters   Total    Crit   High   Med    Low
─────────────────────────── ────────── ──────── ────── ────── ────── ──────
AMS_Zubin_Stage            2          150      10     30     80     30
─────────────────────────── ────────── ──────── ────── ────── ────── ──────
SUBTOTAL (Quality & Test)  2          150      10     30     80     30

┌────────────────────────────────────────────────────────────────────┐
│ 🌍 ENVIRONMENT: Production                                         │
│    Business: Adobe-AMS-Global                                      │
│    Region: United States (us)                                      │
└────────────────────────────────────────────────────────────────────┘

Group Name                  Clusters   Total    Crit   High   Med    Low
─────────────────────────── ────────── ──────── ────── ────── ────── ──────
Prod_Cluster               3          200      15     40     100    45
─────────────────────────── ────────── ──────── ────── ────── ────── ──────
SUBTOTAL (Production)      3          200      15     40     100    45

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GRAND TOTAL (ALL ENVIRONMENTS)  5      350      25     70     180    75
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## OpenTelemetry Logs

OTel logs now include `deployment.environment` for filtering:

```json
{
  "Resource": {
    "service.name": "trend-micro-container-security",
    "deployment.environment": "Quality & Test",
    "cloud.account.name": "Adobe Managed Services QTE"
  },
  "Attributes": {
    "group.name": "AMS_Zubin_Stage",
    "vulnerability.total": 150,
    "vulnerability.severity.critical": 10
  }
}
```

## Grafana Queries

### Filter by environment:
```
# Production only
{deployment.environment="Production"} | json

# Quality & Test only
{deployment.environment="Quality & Test"} | json

# All environments
{deployment.environment=~".+"} | json
```

### Compare environments:
```
sum by (deployment.environment) (
  rate({deployment.environment=~".+"} | json | unwrap vulnerability.total [5m])
)
```

## Available Environments

**Currently Configured:**
- ✅ `quality_test` - Adobe Managed Services QTE (Australia)
- ✅ `production` - Adobe-AMS-Global (United States)
- ⚪ `staging` - Not configured
- ⚪ `development` - Not configured

## Credentials Management

Credentials are automatically fetched from `pass` (GPG-encrypted):

```bash
# View available credentials
pass TrendMicro/

# View specific environment token
pass TrendMicro/quality_test/api_token
pass TrendMicro/production/api_token
```

## Adding New Environments

1. **Add credentials to pass:**
   ```bash
   pass insert -m TrendMicro/staging/api_token
   pass insert TrendMicro/staging/api_base_url
   pass insert TrendMicro/staging/business_id
   ```

2. **Update `config/deployment_config.json`:**
   Add environment details (business name, region, etc.)

3. **Update `config/environments.json`:**
   Add environment configuration (API endpoints, timeouts, etc.)

4. **Test:**
   ```bash
   python3 get_container_vulnerabilities.py -e staging --summary-only
   ```

## Common Use Cases

### Daily Automated Scan (All Environments)
```bash
# Cron job - scan all environments daily
0 2 * * * cd /path/to/project && python3 get_container_vulnerabilities.py --quiet
```

### Production-Only Monitoring
```bash
# Only scan production, append OTel logs
python3 get_container_vulnerabilities.py -e production
```

### Compare QTE vs Production
```bash
# Scan both and generate reports
python3 get_container_vulnerabilities.py -e quality_test -e production --grafana-dashboard
```

### Specific Group Tracking
```bash
# Track specific group across all environments
python3 get_container_vulnerabilities.py --group-name "AMS_Zubin_Stage"
```

## Key Features

✅ **Automatic environment detection** - Scans all configured environments by default  
✅ **Per-environment credentials** - Automatically fetches from pass  
✅ **Grouped results** - Clear separation by environment with subtotals  
✅ **Environment labels in OTel** - Filter and compare in Grafana  
✅ **Backward compatible** - Works exactly like before without --environment flag  
✅ **Smart error handling** - Continues scanning if one environment fails  

## Related Documentation

- `docs/PASS_INTEGRATION.md` - Pass integration and credential management
- `docs/CONFIGURATION.md` - Multi-environment configuration details
- `docs/CONTAINER_SECURITY.md` - Container security scanning guide
- `PASS_QUICK_REFERENCE.md` - Quick pass commands

## Need Help?

```bash
# View all options
python3 get_container_vulnerabilities.py --help

# Test configuration
python3 lib/config_loader.py
```

---
**Last Updated:** 2026-01-20  
**Version:** 1.0.0
