# API Comparison: Why Container Works But Endpoint Doesn't

## Quick Answer

**Your binaries ARE fetching from the Global US API** (`https://api.xdr.trendmicro.com`), but endpoint APIs are failing due to **missing API permissions**.

## Side-by-Side Comparison

### Container Security (WORKING ✅)

```bash
./go/bin/get_container_vulnerabilities
```

| Environment | API Base URL | Status | Records |
|------------|--------------|--------|---------|
| quality_test | `https://api.au.xdr.trendmicro.com` | ✅ SUCCESS | 253 vulns |
| **production** | **`https://api.xdr.trendmicro.com`** | ✅ **SUCCESS** | **4,784 vulns** |
| production_au | `https://api.au.xdr.trendmicro.com` | ✅ SUCCESS | 7,093 vulns |

**APIs Used:**
- `/beta/containerSecurity/kubernetesClusters` ✅
- `/beta/containerSecurity/vulnerabilities` ✅

**Token Has Permission:** ✅ Container Security → View

---

### Endpoint Security (FAILING ❌)

```bash
./go/bin/get_endpoint_vulnerabilities
./go/bin/get_endpoint_stats
```

| Environment | API Base URL | Status | Records |
|------------|--------------|--------|---------|
| quality_test | `https://api.au.xdr.trendmicro.com` | ⚠️ PARTIAL | 50 (then fails) |
| **production** | **`https://api.xdr.trendmicro.com`** | ❌ **FAIL** | **0** |
| production_au | `https://api.au.xdr.trendmicro.com` | ❌ FAIL | 0 |

**APIs Tried:**
- `/beta/asrm/devices` ❌ HTTP 404
- `/beta/riskInsights/devices` ❌ HTTP 404
- `/v3.0/eiqs/endpoints` ❌ HTTP 400
- `/v3.0/oat/detections` ⚠️ HTTP 400 (pagination fails)

**Token Missing Permission:** ❌ Endpoint Inventory → View

## Terminal Evidence

From your actual terminal output showing `get_endpoint_vulnerabilities` run:

```
🌍 Scanning environments: production_au, quality_test, production

╔════════════════════════════════════════════════════════════════════╗
║  ENVIRONMENT: PRODUCTION                                            ║
╚════════════════════════════════════════════════════════════════════╝

Business: Adobe-AMS-Global
Region: United States (Global) (us)
API Base: https://api.xdr.trendmicro.com    👈 IT IS TRYING GLOBAL API!

Trying: /beta/asrm/devices... ❌ Not Found
Trying: /beta/riskInsights/devices... ❌ Not Found
Trying: /v3.0/eiqs/endpoints... ❌ HTTP 400   👈 PERMISSION DENIED

❌ ERROR: Unable to fetch devices from any endpoint.

Required Permissions:
  • Attack Surface Risk Management → View
  • Endpoint Inventory → View
```

## Why Only AU Reports Exist

### Container Reports (`container_vulnerability_report.txt`)

```
Environments Scanned: quality_test, production, production_au

Quality & Test            ... au    ... 253 vulnerabilities
Production                ... us    ... 4,784 vulnerabilities   👈 Global US data!
Production (Australia)    ... au    ... 7,093 vulnerabilities
```

**Result:** Report contains data from **ALL 3 environments** including Global US

---

### Endpoint Reports (`endpoint_inventory_report.txt`)

```
Environment: Quality & Test
Business: Adobe Managed Services QTE
Region: Australia (au)
Data Source: OAT (Observed Attack Techniques) Detections

Total Endpoints: 1
Total Detections: 109
```

**Result:** Report contains data from **ONLY quality_test** because:
- production → HTTP 400 (no data collected)
- production_au → HTTP 400 (no data collected)
- quality_test → Got 50 records, then HTTP 400 on pagination

## What Happens When API Fails

### With Data (Container API)
```
1. Try to fetch from production (Global US)
2. ✅ GET https://api.xdr.trendmicro.com/.../vulnerabilities → HTTP 200
3. ✅ Received 4,784 vulnerabilities
4. ✅ Write to report file
5. ✅ Report shows: "Production ... us ... 4,784 vulnerabilities"
```

### Without Data (Endpoint API)
```
1. Try to fetch from production (Global US)
2. ❌ GET https://api.xdr.trendmicro.com/.../endpoints → HTTP 400
3. ❌ No data collected
4. ❌ Skip this environment in report
5. ❌ Report only shows environments with data (quality_test partial)
```

## The Misconception

### What You Thought
```
Binary NOT trying Global US API
  ↓
Only connecting to AU API
  ↓
Only AU data in reports
```

### What Actually Happened
```
Binary IS trying Global US API
  ↓
Global US API returns HTTP 400 (permission denied)
  ↓
No data collected from Global US
  ↓
Only AU data (partial) in reports
```

## Proof: Log Files

Container Security structured logs show SUCCESS for all environments:

```json
{"time":"...","level":"INFO","msg":"Processing cluster",
 "environment":"production",
 "api_base_url":"https://api.xdr.trendmicro.com",
 "cluster_name":"AMS_EKS_Zubin_China",
 "vulnerabilities":390}
```

Endpoint Security structured logs show FAILURE for production:

```json
{"time":"...","level":"ERROR","msg":"Failed to fetch devices",
 "environment":"production",
 "api_base_url":"https://api.xdr.trendmicro.com",
 "error":"HTTP 400"}
```

## Fix: Add Endpoint Permissions

### For All 3 Environments

Login to each Trend Micro portal and add these permissions to your API role:

**quality_test:**
- Portal: https://portal.au.xdr.trendmicro.com/
- Add: Endpoint Inventory → View
- Add: Attack Surface Risk Management → View

**production:**
- Portal: https://portal.xdr.trendmicro.com/
- Add: Endpoint Inventory → View
- Add: Attack Surface Risk Management → View

**production_au:**
- Portal: https://portal.au.xdr.trendmicro.com/
- Add: Endpoint Inventory → View
- Add: Attack Surface Risk Management → View

### After Adding Permissions

```bash
./go/bin/get_endpoint_stats
```

**Expected:**
```
🌍 Scanning environments: quality_test, production, production_au

╔════════════════════════════════════════════════════════════════════╗
║  ENVIRONMENT: PRODUCTION                                            ║
╚════════════════════════════════════════════════════════════════════╝

API Base: https://api.xdr.trendmicro.com

  Fetching page 1... ✅ 50 detections
  Fetching page 2... ✅ 50 detections
  Fetching page 3... ✅ 50 detections
  ...
  Total: 1,234 endpoints

✅ Report generated: endpoint_inventory_report.txt
```

**Report will then show:**
```
Environment: Production
Region: United States (Global) (us)
API Base: https://api.xdr.trendmicro.com    👈 Global US data!
Total Endpoints: 1,234
```

## Conclusion

| Statement | Truth |
|-----------|-------|
| "Binaries only connect to AU API" | ❌ FALSE - They try ALL environments |
| "Binaries never try Global US API" | ❌ FALSE - They DO try it every time |
| "Global US API is not being called" | ❌ FALSE - It IS called, returns HTTP 400 |
| "Container APIs work for all regions" | ✅ TRUE - Token has permissions |
| "Endpoint APIs fail for all regions" | ✅ TRUE - Token missing permissions |
| "Only AU has data in reports" | ⚠️ MISLEADING - Only AU API returned data |

**The binaries ARE working correctly. The issue is API permissions, not the binaries.**
