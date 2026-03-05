# Endpoint API Discovery - Results & Available Statistics

**Date:** January 20, 2026  
**Status:** Discovery Complete - Awaiting User Decision

---

## Summary

After testing **18 different API endpoints**, I found **2 working endpoints**, but only one provides endpoint-related data.

---

## Working API Endpoint

### ✅ `/v3.0/oat/detections` - Observed Attack Techniques

**Status:** Functional ✓  
**Total Records:** 117 detections  
**Endpoint Records:** 81 (69% of detections)

**What it provides:**
- Endpoint names
- Agent GUIDs
- IP addresses (IPv4 and IPv6)
- MAC addresses
- Hostnames
- Detection activity per endpoint
- Timeline of security events

**What it is:**
- Security detection/threat data
- Shows endpoints that have HAD security detections
- **NOT a complete endpoint inventory**
- Only shows endpoints with recent security activity

---

## Available Endpoint Fields

From the OAT detections API, each record contains:

### Top-Level Fields:
```
• entityName         - Endpoint name (with IP in parentheses)
• entityType         - "endpoint" or "container"
• uuid               - Detection UUID
• detectedDateTime   - When detection occurred
• source             - "endpointActivityData" or "containerActivityData"
```

### Endpoint Object Fields:
```
• endpointName       - Clean endpoint hostname
• agentGuid          - Unique agent identifier
• ips                - Array of IP addresses (IPv4/IPv6)
```

### Detail Object Fields (Endpoint Context):
```
• endpointGuid       - Agent GUID
• endpointHostName   - Hostname
• endpointIp         - IP addresses array
• endpointMacAddress - MAC addresses array
• clusterId          - Kubernetes cluster ID (if containerized)
• clusterName        - Cluster name (if applicable)
```

---

## Current Data Sample (Your Environment)

Based on the 117 detections analyzed:

**Unique Endpoints with Detections:**
- QualcommCN-dev-dispatcher1cnnorth1-b86
- ams-eks-cluster-stage-0252c8f7b63f894e4
- ams-eks-cluster-stage-048e8306fbda80b0b
- ams-eks-cluster-stage-09b936b5fdca3bf1a
- ams-eks-cluster-stage-0ca41af3176e145b7

**Distribution:**
- Endpoint detections: 81 (69%)
- Container detections: 36 (31%)

**Timeline:** Last hour (2026-01-20 01:53 to 02:51 UTC)

---

## What Statistics CAN Be Calculated

From the OAT detections API, I can provide:

### 1. Endpoint Detection Activity
- ✅ Total endpoints with detections
- ✅ Total security detections
- ✅ Detections per endpoint
- ✅ Detection timeline (hourly, daily trends)

### 2. Endpoint Identification
- ✅ Unique endpoint names
- ✅ Unique agent GUIDs
- ✅ IP address inventory (from detections)
- ✅ MAC address inventory
- ✅ Hostname list

### 3. Detection Distribution
- ✅ Endpoints vs Containers (entity type)
- ✅ Detection sources (endpoint vs container activity)
- ✅ Most active endpoints (by detection count)
- ✅ Detection patterns over time

### 4. Cluster Association
- ✅ Kubernetes cluster IDs (for containerized workloads)
- ✅ Endpoints per cluster
- ✅ Container vs host detection split

---

## What Statistics CANNOT Be Calculated

The OAT API does NOT provide:

### ❌ Complete Endpoint Inventory
- Cannot get total number of ALL endpoints
- Only shows endpoints with recent detections
- Missing quiet/inactive endpoints

### ❌ Managed vs Unmanaged Status
- No protection manager field
- No agent installation status
- No product codes or versions

### ❌ OS Distribution
- No operating system information
- No OS version details
- No platform type

### ❌ Agent Health Status
- No agent status (online/offline)
- No agent version information
- No last seen timestamp

---

## Alternative Approach: Portal UI Export

For **complete endpoint inventory** statistics, you should:

1. **Export from Portal UI**
   - Go to: https://portal.au.xdr.trendmicro.com/
   - Navigate to: Endpoint Security → Endpoint Inventory
   - Click "Export" to download CSV
   - Use spreadsheet to calculate:
     - Total endpoints
     - Managed vs unmanaged
     - OS distribution
     - Agent status
     - Product installation stats

2. **Manual Verification**
   - Check what endpoint data is visible in portal
   - Compare with API results
   - Identify any discrepancies

---

## Proposed Statistics for `get_endpoint_stats.py`

Given the available data, I propose the script should calculate:

### Option A: Detection-Based Statistics (Using OAT API)
```
1. Endpoint Detection Activity:
   - Total unique endpoints with detections
   - Total security detections (last 24 hours / 7 days)
   - Average detections per endpoint
   - Most active endpoints (top 10)

2. Endpoint Identification:
   - Unique endpoint hostnames
   - Unique agent GUIDs
   - IP address list
   - MAC address list

3. Entity Distribution:
   - Endpoint detections: X
   - Container detections: Y
   - Total: X + Y

4. Detection Timeline:
   - Hourly detection chart
   - Peak activity periods
   - Date range covered

5. Cluster Analysis:
   - Endpoints by cluster
   - Container vs host breakdown
```

### Option B: Portal Export + Manual Entry
```
Create a template script that:
1. Documents the correct Portal export process
2. Provides CSV parsing code
3. Calculates traditional endpoint stats:
   - Total endpoints
   - Managed/unmanaged split
   - OS distribution
   - Agent status
```

### Option C: Hybrid Approach
```
1. Use OAT API for:
   - Active endpoints (with recent detections)
   - Security activity metrics

2. Document manual steps for:
   - Complete inventory (Portal export)
   - Agent health status
   - Full endpoint details
```

---

## Questions for You

Please choose what you want the `get_endpoint_stats.py` script to do:

**1. Which data source should we use?**
   - a) OAT Detections API (endpoints with security activity) ← Available now
   - b) Wait/skip until correct endpoint inventory API is found
   - c) Create CSV parser for Portal export

**2. If using OAT API, which statistics do you want?**
   - a) All detection-based statistics (Option A above)
   - b) Just unique endpoint count and names
   - c) Focus on security activity metrics
   - d) Custom selection (specify which)

**3. Should the output include?**
   - a) Total endpoint count (from detections only)
   - b) Endpoint list with detection counts
   - c) Detection timeline/trends
   - d) All of the above
   - e) Custom (specify)

**4. Output format preference?**
   - a) Text report (like container vulnerability report)
   - b) JSON output
   - c) CSV file
   - d) Both text and JSON

---

## Current Status

**Files Created:**
- `discover_endpoint_api.py` - Tests 18 different API paths
- `explore_oat_endpoint_data.py` - Analyzes OAT detection data
- `ENDPOINT_API_FINDINGS.md` - This document
- `discovery_output.log` - Full discovery results

**Next Steps:**
1. Review this document
2. Choose which statistics you want
3. I'll update `get_endpoint_stats.py` accordingly
4. Run the updated script
5. Generate your endpoint statistics report

---

## Curl Command for OAT API

To manually test the working endpoint:

```bash
curl -X GET "https://api.au.xdr.trendmicro.com/v3.0/oat/detections?top=50" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json"
```

**Response includes:**
- totalCount: Total number of detections
- items: Array of detection objects (each with endpoint data)
- nextLink: URL for pagination

---

**Waiting for your decision on which statistics to implement!**
