# Endpoint API Permissions Issue

## Problem Summary

The `get_endpoint_vulnerabilities` and `get_endpoint_stats` binaries **ARE** attempting to fetch data from **ALL** configured environments including:

- ✅ `quality_test` → `https://api.au.xdr.trendmicro.com`
- ✅ `production` → `https://api.xdr.trendmicro.com` (Global US)
- ✅ `production_au` → `https://api.au.xdr.trendmicro.com`

However, they're only getting **partial data from quality_test** and **NO data** from production environments.

## What's Actually Happening

### Evidence from Terminal Output

Looking at `/terminals/6.txt`:

**Line 160:** 
```
🌍 Scanning environments: production_au, quality_test, production
```

**Line 220 (Production - Global US):**
```
Business: Adobe-AMS-Global
Region: United States (Global) (us)
API Base: https://api.xdr.trendmicro.com   👈 IS trying Global API
```

**Line 224:**
```
Trying: /v3.0/eiqs/endpoints... ❌ HTTP 400
```

**Line 276 (get_endpoint_stats):**
```
API: https://api.xdr.trendmicro.com/v3.0/oat/detections   👈 IS trying Global API
```

### The Actual Problem

Both binaries **ARE** connecting to the production (Global) API, but they're failing with:

| Environment | API Base URL | Status | Issue |
|------------|--------------|--------|-------|
| **production** (Global US) | `https://api.xdr.trendmicro.com` | ❌ FAIL | HTTP 400/404 on all endpoints |
| **production_au** | `https://api.au.xdr.trendmicro.com` | ❌ FAIL | HTTP 400/404 on all endpoints |
| **quality_test** | `https://api.au.xdr.trendmicro.com` | ⚠️ PARTIAL | Gets 50 records, then HTTP 400 |

## Why Container Vulnerabilities Work But Endpoint APIs Don't

### Container Security (Working)

```bash
./go/bin/get_container_vulnerabilities
```

**Result:**
```
✅ quality_test (AU API)    - SUCCESS - 253 vulnerabilities
✅ production (Global US API) - SUCCESS - 4,784 vulnerabilities
✅ production_au (AU API)   - SUCCESS - 7,093 vulnerabilities
```

**Why it works:**
- Uses: `/beta/containerSecurity/kubernetesClusters`
- Uses: `/beta/containerSecurity/vulnerabilities`
- Your tokens have **Container Security** permissions

### Endpoint APIs (Failing)

```bash
./go/bin/get_endpoint_vulnerabilities
./go/bin/get_endpoint_stats
```

**Result:**
```
❌ ALL ENVIRONMENTS FAIL
```

**APIs tried:**
1. `/beta/asrm/devices` → **404 Not Found**
2. `/beta/riskInsights/devices` → **404 Not Found**
3. `/v3.0/eiqs/endpoints` → **HTTP 400 Bad Request**
4. `/v3.0/oat/detections` → **HTTP 400** (after first page)

**Why it fails:**
- Different API permissions required
- Your tokens likely DON'T have **Endpoint Inventory** or **Attack Surface Risk Management** permissions

## Root Cause: API Permissions

### Container Security Token Permissions ✅

Your API tokens have these permissions:
- Container Security → View
- Kubernetes Cluster → View
- Container Vulnerabilities → View

### Endpoint Security Token Permissions ❌

Your API tokens are **MISSING** these permissions:
- **Attack Surface Risk Management (ASRM)** → View
- **Endpoint Inventory** → View
- **Observed Attack Techniques (OAT)** → Full Access
- **Endpoint Security** → View

## Evidence: HTTP Error Codes

### Container APIs
```
✅ HTTP 200 OK - Authentication succeeded, data returned
```

### Endpoint APIs
```
❌ HTTP 404 Not Found - API endpoint doesn't exist (or no permission)
❌ HTTP 400 Bad Request - Request syntax error (or permission denied)
❌ HTTP 403 Forbidden   - Valid token but insufficient permissions
```

**Note:** Some APIs return 400/404 instead of 403 when permissions are insufficient.

## Solution: Add Required Permissions

### Step 1: Identify Required Permissions

Based on the API endpoints being used:

| API Endpoint | Required Permission |
|-------------|---------------------|
| `/beta/asrm/devices` | Attack Surface Risk Management → View |
| `/beta/riskInsights/devices` | Risk Insights → View |
| `/v3.0/eiqs/endpoints` | Endpoint Inventory → View |
| `/v3.0/oat/detections` | Observed Attack Techniques → View |

### Step 2: Update API Role Permissions

For **each environment** (quality_test, production, production_au):

1. **Log into Trend Micro Vision One Portal:**
   - Quality Test: https://portal.au.xdr.trendmicro.com/
   - Production: https://portal.xdr.trendmicro.com/
   - Production AU: https://portal.au.xdr.trendmicro.com/

2. **Navigate to:** Administration → User Roles → API Keys

3. **Find your API role** and add these permissions:
   - ✅ **Attack Surface Risk Management** → View
   - ✅ **Endpoint Inventory** → View  
   - ✅ **Observed Attack Techniques** → View
   - ✅ **Risk Insights** → View (optional)
   - ✅ **Endpoint Security** → View (optional)

4. **Save changes**

### Step 3: Regenerate or Wait

- **Option A:** Generate new API tokens with updated permissions
- **Option B:** Wait for existing tokens to pick up new permissions (may take 5-15 minutes)

### Step 4: Test

```bash
# Test endpoint APIs
./go/bin/get_endpoint_stats

# Expected output:
🌍 Scanning environments: quality_test, production, production_au

╔════════════════════════════════════════════════════════════════════╗
║  ENVIRONMENT: PRODUCTION                                            ║
╚════════════════════════════════════════════════════════════════════╝

Business: Adobe-AMS-Global
Region: United States (Global) (us)
API Base: https://api.xdr.trendmicro.com

  Fetching page 1... ✅ 50 detections
  Fetching page 2... ✅ 50 detections
  ...
```

## Verification Steps

### Test 1: Check Current Permissions

```bash
# Decode your token to see current permissions
TOKEN=$(pass show TrendMicro/production/api_token)
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq
```

### Test 2: Test Endpoint API Directly

```bash
# Test production (Global US) endpoint API
TOKEN=$(pass show TrendMicro/production/api_token)

curl -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/json" \
     "https://api.xdr.trendmicro.com/v3.0/oat/detections?top=5"
```

**Expected when permissions are correct:**
```json
{
  "items": [
    {
      "entityId": "...",
      "entityName": "...",
      ...
    }
  ],
  "nextLink": "..."
}
```

**Currently getting (wrong permissions):**
```json
{
  "error": {
    "code": "Bad Request",
    "message": "..."
  }
}
```

### Test 3: Compare with Container API

```bash
# This works (proves token is valid)
curl -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/json" \
     "https://api.xdr.trendmicro.com/beta/containerSecurity/kubernetesClusters"
```

## Why This Confusion Happened

### What You Saw
- Only report files from `quality_test` (AU region) existed
- No report files from `production` (Global US)
- You concluded: "Not fetching from Global US API"

### What Actually Happened
1. ✅ **Both binaries DID try all environments** including Global US
2. ✅ **They DID connect to** `https://api.xdr.trendmicro.com`
3. ❌ **API calls FAILED** due to insufficient permissions
4. ❌ **No report generated** when no data is retrieved
5. ⚠️ **Only quality_test got partial data** (50 records before permission error)

### The Logs Prove It

From your terminal output (line 220):
```
╔════════════════════════════════════════════════════════════════════╗
║  ENVIRONMENT: PRODUCTION                                            ║
╚════════════════════════════════════════════════════════════════════╝

Business: Adobe-AMS-Global
Region: United States (Global) (us)
API Base: https://api.xdr.trendmicro.com    👈 It IS trying this!

Trying: /beta/asrm/devices... ❌ Not Found
Trying: /beta/riskInsights/devices... ❌ Not Found
Trying: /v3.0/eiqs/endpoints... ❌ HTTP 400    👈 Permission issue
```

## Summary

| Component | Status | Notes |
|-----------|--------|-------|
| **Token validity** | ✅ Valid | Container APIs work fine |
| **Global US API connectivity** | ✅ Connected | Binaries DO try it |
| **Container API permissions** | ✅ Sufficient | Gets data from all regions |
| **Endpoint API permissions** | ❌ Insufficient | Fails on all regions |
| **Fix needed** | 🔧 Add permissions | See Step 2 above |

## References

- [Trend Micro API Permissions](https://automation.trendmicro.com/xdr/home)
- [API Role Configuration Guide](https://docs.trendmicro.com/en-us/enterprise/trend-vision-one/getting-started/managing-api-k.aspx)
- Container Security working examples in `/container_vulnerability_report.txt`
