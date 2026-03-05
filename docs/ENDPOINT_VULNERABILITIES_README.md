# Endpoint/Device Vulnerability Scanning - Setup Guide

**Author:** Mukesh Kesharwani (mkesharw@adobe.com)  
**Date:** January 23, 2026  
**Status:** ⚠️ Requires Additional API Permissions

---

## Overview

The `get_endpoint_vulnerabilities.py` script is designed to scan endpoint/device vulnerabilities similar to how `get_container_vulnerabilities.py` scans container vulnerabilities. However, **additional API permissions are required** to access the Device Vulnerabilities API.

---

## Current Status

✅ **Script Created**: `get_endpoint_vulnerabilities.py`  
✅ **Framework Ready**: Follows same patterns as container vulnerability scanner  
❌ **API Access**: Current API role lacks required permissions  
⚠️  **Action Required**: Update API role permissions (see below)

---

## Why This Is Needed

Your current API role (`Container_Security_Reader`) has permissions for:
- ✅ Container Security → View
- ✅ Kubernetes Clusters → View
- ✅ Container Vulnerabilities → View

But it **does NOT** have permissions for:
- ❌ Attack Surface Risk Management → View
- ❌ Endpoint Inventory → View  
- ❌ Risk Insights → View

These additional permissions are needed to access the **Device Vulnerabilities API**.

---

## What Data Will Be Available

Once permissions are granted, the script will provide:

### Endpoint Vulnerability Data
- Device/endpoint inventory
- Vulnerabilities per device  
- Severity counts (Critical, High, Medium, Low)
- Risk scores per device
- CVE details
- Patch status
- OS version information

### Output Formats (Same as Container Scanner)
1. **CSV** (`endpoint_vulnerability_summary.csv`) - Excel/database ready
2. **TXT** (`endpoint_vulnerability_report.txt`) - Human-readable
3. **JSONL** (`endpoint_vulnerability_metrics.jsonl`) - Grafana/Loki integration

---

## Setup Instructions

### Step 1: Update API Role Permissions

1. **Log into Trend Vision One Console**:
   - US/Global: https://portal.xdr.trendmicro.com/
   - Australia: https://portal.au.xdr.trendmicro.com/

2. **Navigate to**: Administration → User Roles

3. **Find Your Custom API Role**:
   - Current role name: `Container_Security_Reader` (or similar)
   - Click on it to edit

4. **Add These Permissions**:
   ```
   ✅ Attack Surface Risk Management → View
   ✅ Endpoint Inventory → View  
   ✅ Risk Insights → View
   ✅ Device Risk Assessment → View (if available)
   ```

5. **Save the Role**

6. **Wait 5 Minutes** for changes to propagate

### Step 2: Verify Modules Are Enabled

Check if these Trend Micro modules are active in your account:

1. **Attack Surface Risk Management (ASRM)**
   - Go to: Zero Trust Risk Insights → Attack Surface
   - If you see "Module not enabled", contact your Trend Micro account manager

2. **Endpoint Sensor (XDR)**
   - Go to: Endpoint Security → Endpoint Inventory
   - Should show list of managed endpoints

3. **Container Security**
   - Already enabled ✅ (working in your current setup)

**If modules are not enabled**: Contact your Trend Micro account manager or sales representative to enable Attack Surface Risk Management.

### Step 3: Test the Script

After updating permissions:

```bash
# Test with production environment
python3 get_endpoint_vulnerabilities.py --environment production

# If successful, you should see:
# ✅ Found X devices
# ✅ Fetching vulnerabilities for each device...
```

### Step 4: Run Regular Scans

Once working, set up automated scans:

```bash
# Scan all environments
python3 get_endpoint_vulnerabilities.py

# Scan specific environment
python3 get_endpoint_vulnerabilities.py --environment production

# Quiet mode for cron
python3 get_endpoint_vulnerabilities.py --quiet
```

---

## Testing Current Permissions

To see what the script does with current permissions:

```bash
# Show setup help
python3 get_endpoint_vulnerabilities.py --setup-help

# Try to run scan (will show permission errors)
python3 get_endpoint_vulnerabilities.py --environment production
```

**Expected Output**:
```
❌ ERROR: Unable to fetch devices from any endpoint.

Possible causes:
  1. API role lacks required permissions
  2. Attack Surface Risk Management module not enabled
  3. No devices enrolled in Trend Micro Vision One

Required Permissions:
  • Attack Surface Risk Management → View
  • Endpoint Inventory → View
```

This is **correct behavior** - the script is working as designed and properly detecting the permission limitation.

---

## Alternative: Current Endpoint Stats Script

While waiting for permissions, you can use the existing script:

### `get_endpoint_stats_OLD_OAT.py`

This script uses the **OAT (Observed Attack Techniques)** API, which **IS** accessible with your current role:

```bash
# Run endpoint stats (uses OAT detections)
python3 get_endpoint_stats_OLD_OAT.py

# This provides:
# - Unique endpoints with recent security detections
# - Detection counts by source (Container vs Endpoint)
# - Entity type distribution
# - Endpoint names and hostnames
```

**Important Notes**:
- ⚠️ This shows **detections**, not **vulnerabilities**
- ⚠️ Only includes endpoints with recent security events
- ⚠️ NOT a complete endpoint inventory
- ⚠️ NOT the same as vulnerability scanning

---

## Comparison: OAT vs Device Vulnerabilities

| Feature | OAT Detections (Current Access) | Device Vulnerabilities (Needs Permissions) |
|---------|--------------------------------|-------------------------------------------|
| **API Endpoint** | `/v3.0/oat/detections` | `/beta/asrm/devices` + `/vulnerabilities` |
| **Data Type** | Security detections/events | CVE vulnerabilities |
| **Coverage** | Only endpoints with detections | All managed endpoints |
| **Severity** | Detection risk level | CVE severity (Critical/High/Med/Low) |
| **Use Case** | Incident response | Vulnerability management |
| **Patch Status** | ❌ Not available | ✅ Available |
| **CVE Details** | ❌ Not available | ✅ Available |
| **Complete Inventory** | ❌ Partial | ✅ Complete |

---

## Questions & Troubleshooting

### Q: Why don't I have access?

The API role was originally created specifically for **Container Security** monitoring. Device/endpoint vulnerability scanning is a separate module with separate permissions.

### Q: Will this affect my container scanning?

No. The container vulnerability scanner (`get_container_vulnerabilities.py`) continues to work perfectly. Adding endpoint permissions will give you **additional** capabilities.

### Q: How long does it take to get permissions?

- **Update role permissions**: Immediate (+ 5 min propagation)
- **Enable ASRM module**: Contact Trend Micro (may require license discussion)

### Q: Can I use both scripts?

Yes! Once you have endpoint vulnerability access, you can run:
- `get_container_vulnerabilities.py` - For container vulnerabilities ✅
- `get_endpoint_vulnerabilities.py` - For device vulnerabilities (after setup)

### Q: What if my organization doesn't have ASRM?

Contact your Trend Micro account manager to discuss:
1. Adding Attack Surface Risk Management to your license
2. Enabling Endpoint Sensor (XDR) if not already active
3. Pricing and deployment timeline

---

## Next Steps

1. **⚠️ Required**: Update API role permissions (Step 1 above)
2. **⚠️ Verify**: Check if ASRM module is enabled (Step 2 above)
3. **✅ Test**: Run the script again (Step 3 above)
4. **✅ Automate**: Set up cron jobs for regular scanning (Step 4 above)

---

## Support

### Internal Contact
- **Author**: Mukesh Kesharwani
- **Email**: mkesharw@adobe.com

### Trend Micro Support
- **Portal**: Your regional portal (US/AU)
- **Documentation**: https://automation.trendmicro.com/xdr/api-beta/
- **Account Manager**: Contact for module/license questions

---

## Script Comparison

| Script | Purpose | Status | Required Permissions |
|--------|---------|--------|---------------------|
| `get_container_vulnerabilities.py` | Container vulnerability scanning | ✅ Working | Container Security → View |
| `get_endpoint_vulnerabilities.py` | Device vulnerability scanning | ⚠️ Needs Setup | ASRM + Endpoint Inventory → View |
| `get_endpoint_stats_OLD_OAT.py` | Endpoint detection stats (OAT) | ✅ Working | OAT Detections → View (already have) |

---

**Last Updated**: January 23, 2026
