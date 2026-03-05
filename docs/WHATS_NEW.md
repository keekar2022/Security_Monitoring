# What's New - Endpoint Inventory Scanner

**Date:** January 27, 2026  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## 🎉 New Feature: Enhanced Endpoint Inventory & Statistics

We've created a production-ready endpoint inventory scanner that extracts comprehensive endpoint data from OAT (Observed Attack Techniques) detections!

### ✅ What's Available NOW (No Setup Required)

#### New Script: `get_endpoint_stats.py`

A completely rewritten endpoint inventory scanner that follows the same high-quality patterns as your container vulnerability scanner.

**Key Features:**
- 📊 **Multi-Environment Support** - Scans Quality & Test, Production, Production AU
- 📁 **Three Output Formats** - CSV, TXT, JSONL (same as containers)
- 🔍 **Comprehensive Endpoint Data**:
  - Endpoint names, GUIDs, IP addresses, MAC addresses
  - Operating system info (name, version, description)
  - Trend Micro product/agent versions
  - Security detection counts by severity
  - Risk scores per endpoint
  - MITRE ATT&CK tactic and technique coverage
  - First seen / Last seen timestamps
- 🔄 **Automation Ready** - Cron-friendly with `--quiet` mode
- 📈 **Grafana Integration** - OpenTelemetry-compliant JSONL format
- 🎯 **Pass Integration** - Uses secure credential storage

### 📊 Sample Output

**From Your Quality & Test Environment:**
- **Endpoint Found:** QualcommCN-dev-dispatcher1cnnorth1-b86
- **OS:** Linux Red Hat Enterprise 8
- **Detections:** 109 security events
- **Risk Score:** 19
- **MITRE Techniques:** 9 techniques across 7 tactics

### 🚀 Quick Start

```bash
# Scan all environments
python3 get_endpoint_stats.py

# View human-readable report
cat endpoint_inventory_report.txt

# View CSV (Excel-ready)
cat endpoint_inventory_summary.csv

# View JSONL (Grafana/Loki)
cat endpoint_inventory_metrics.jsonl
```

### 📁 Files Generated

All three formats contain the same core data:

1. **`endpoint_inventory_summary.csv`**
   - One row per endpoint
   - 24 columns including detections, risk score, MITRE ATT&CK data
   - Excel/Google Sheets/database ready

2. **`endpoint_inventory_report.txt`**
   - Human-readable formatted report
   - Summary statistics
   - Top 10 highest risk endpoints
   - Detailed endpoint information

3. **`endpoint_inventory_metrics.jsonl`**
   - OpenTelemetry-compliant format
   - One JSON object per line (per endpoint)
   - Ready for Grafana/Loki/Prometheus

---

## 📋 Important Notes

### What This Scanner Provides

✅ **Endpoint Inventory** - From OAT detection data  
✅ **Security Detection Statistics** - Counts by severity  
✅ **Risk Scoring** - Calculated from detection severity  
✅ **MITRE ATT&CK Coverage** - Tactics and techniques observed  
✅ **Multi-Environment** - All configured environments  
✅ **Standard Formats** - CSV, TXT, JSONL  

### What This Scanner Does NOT Provide

❌ **CVE Vulnerability Lists** - Requires ASRM module  
❌ **Patch Status** - Requires ASRM module  
❌ **Complete Endpoint Inventory** - Only shows endpoints with detections  

### Data Source Explanation

This script uses the **OAT (Observed Attack Techniques) API**, which tracks security events and detections on endpoints. This means:

- **Only endpoints with recent security detections appear** in the inventory
- If an endpoint has no detections, it won't be included
- Detection counts indicate **security activity**, not vulnerabilities
- This is NOT a replacement for CVE vulnerability scanning (use ASRM for that)

**Think of it as:**
- 🔍 "Security event log analysis" → Endpoint Stats (this script)
- 🐛 "CVE vulnerability scanning" → Endpoint Vulnerabilities (needs ASRM)

---

## 🆚 Comparison with Container Scanner

| Feature | Container Scanner | Endpoint Scanner (New!) |
|---------|------------------|-------------------------|
| **Status** | ✅ Ready | ✅ Ready |
| **Data Type** | Container CVEs | Security Detections |
| **Source** | Container Security API | OAT Detections API |
| **Setup Required** | ❌ No | ❌ No |
| **Multi-Environment** | ✅ Yes | ✅ Yes |
| **CSV/TXT/JSONL** | ✅ Yes | ✅ Yes |
| **Grafana Ready** | ✅ Yes | ✅ Yes |
| **Risk Scoring** | ✅ Yes | ✅ Yes |
| **MITRE ATT&CK** | ❌ No | ✅ Yes |
| **Complete Inventory** | ✅ Yes (all containers) | ⚠️ Partial (endpoints with detections) |

---

## 📚 Documentation

### New Documentation Files

1. **`docs/ENDPOINT_INVENTORY_GUIDE.md`** - Complete guide
   - Usage instructions
   - Command reference
   - Output format details
   - Grafana integration
   - Troubleshooting
   - Automation examples

2. **Updated `README.md`**
   - Added endpoint inventory scanner section
   - Updated project structure
   - Added usage examples

### Existing Documentation

- **`ENDPOINT_VULNERABILITIES_README.md`** - For CVE scanning (requires ASRM)
- **`docs/CONTAINER_SECURITY.md`** - Container vulnerability guide
- **`docs/GRAFANA_GUIDE.md`** - Grafana/Loki integration

---

## 🔄 Migration from Old Script

### Old Script: `get_endpoint_stats_OLD_OAT.py`

The old endpoint stats script has been **replaced** with the new enhanced version.

**Key Improvements:**
- ✅ Multi-environment support (old: single environment)
- ✅ CSV output (old: text only)
- ✅ JSONL/OTel format (old: not available)
- ✅ Risk scoring (old: basic stats)
- ✅ MITRE ATT&CK mapping (old: not available)
- ✅ Better error handling (old: basic)
- ✅ Pass integration (old: manual config)

**Migration:**
```bash
# Old way (deprecated)
python3 get_endpoint_stats_OLD_OAT.py

# New way (recommended)
python3 get_endpoint_stats.py
```

The old script is retained for reference but should not be used for new work.

---

## 🔮 Future: Full CVE Vulnerability Scanning

### When ASRM Module is Enabled

Once you enable the Attack Surface Risk Management (ASRM) module from Trend Micro, you'll be able to use:

**`get_endpoint_vulnerabilities.py`** - Full CVE vulnerability scanner

This will provide:
- ✅ Complete endpoint inventory (all endpoints, not just those with detections)
- ✅ CVE vulnerability lists per endpoint
- ✅ Vulnerability severity (Critical, High, Medium, Low)
- ✅ Patch status
- ✅ Same output formats (CSV, TXT, JSONL)
- ✅ Same multi-environment support

**Status:** Script is ready, just needs ASRM module enabled in your account.

**Documentation:** See `ENDPOINT_VULNERABILITIES_README.md` for setup instructions.

---

## 📊 Example Output

### Quality & Test Environment

**Scanned:** 182 detections across 4 pages  
**Found:** 1 unique endpoint

**Endpoint Details:**
```
Name: QualcommCN-dev-dispatcher1cnnorth1-b86
GUID: 1282573b-8d6e-48a1-adb5-247a3b583f8d
IPs: 10.43.0.22, fe80::15:c0ff:fe59:27fd
OS: Linux Red Hat Enterprise 8
Product: 751 v1.0.409
Detections: 109 (0 Critical, 0 High, 1 Medium, 17 Low, 92 Info)
Risk Score: 19
MITRE Tactics: 7
MITRE Techniques: 9 (T1021.004, T1033, T1057, T1059.004, T1082, ...)
```

### Production (Australia) Environment

**Scanned:** 180 detections  
**Found:** 1 unique endpoint (same as QTE)

---

## 🤝 Credits

**Developed by:** Mukesh Kesharwani (mkesharw@adobe.com)  
**Based on:** Successful patterns from `get_container_vulnerabilities.py`  
**API Source:** Trend Micro Vision One OAT Detections API  
**Version:** 2.0.0

---

## 🆘 Support

### Questions?

- **Setup Help**: See `docs/ENDPOINT_INVENTORY_GUIDE.md`
- **API Issues**: Run `./verify_pass_tokens.sh`
- **ASRM Setup**: See `ENDPOINT_VULNERABILITIES_README.md`
- **Contact**: mkesharw@adobe.com

### Quick Links

- **Run Scanner**: `python3 get_endpoint_stats.py`
- **View Report**: `cat endpoint_inventory_report.txt`
- **View CSV**: `cat endpoint_inventory_summary.csv`
- **Read Guide**: `cat docs/ENDPOINT_INVENTORY_GUIDE.md`

---

**Enjoy your new endpoint visibility! 🎉**

*Last Updated: January 27, 2026*
