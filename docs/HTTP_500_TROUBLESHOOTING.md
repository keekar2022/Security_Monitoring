# HTTP 500 Error Troubleshooting Guide

## Problem Summary

When running `get_container_vulnerabilities`, all three Kubernetes clusters return:

```
• AMS_EKS_SSA_AU_Stage: API returned status 500
• AMS_EKS_Stage_01: API returned status 500  
• AMS_RepoSvc_Canada_Stage: API returned status 500
```

## Understanding HTTP 500

### What It Is

**HTTP 500 = Internal Server Error**

This means the **Trend Micro API server** is experiencing an internal error when processing your request.

### What It Is NOT

| Error Code | Meaning | Your Situation |
|------------|---------|----------------|
| 401 Unauthorized | Invalid or missing token | ❌ **Not your issue** - you'd see "unauthorized" message |
| 403 Forbidden | Valid token but insufficient permissions | ❌ **Not your issue** - you'd see "forbidden" or "access denied" |
| 500 Internal Server Error | Server-side problem | ✅ **This is what you have** |

### Implications

1. ✅ **Your token is VALID** - authentication passed successfully
2. ✅ **Your token has PERMISSIONS** - authorization passed successfully  
3. ❌ **The API server failed** to process your request after authentication

## Root Cause Analysis

### API Endpoint Being Called

```
GET {base_url}/beta/containerSecurity/vulnerabilities
```

Key observations:
- **Beta API**: The `/beta/` prefix indicates this is a beta endpoint, which may be:
  - Less stable than production endpoints
  - Undergoing active development
  - Subject to breaking changes
  - May have intermittent availability

### Request Parameters

```
Query Parameters:
  - top: 50
  - orderBy: firstDetectedDateTime desc

Headers:
  - Authorization: Bearer {token}
  - Content-Type: application/json
  - Accept: application/json
  - TMV1-Filter: clusterId eq '{cluster-id}'
```

### Possible Causes

1. **API Service Degradation**
   - Trend Micro API experiencing outage
   - Regional API endpoint down
   - Database issues on Trend Micro's side

2. **Beta API Instability**
   - Beta endpoint under maintenance
   - Breaking changes rolled out
   - API version compatibility issues

3. **Query/Filter Issues**
   - The `TMV1-Filter` might trigger a server bug
   - The `orderBy` clause might cause database timeout
   - Cluster IDs might have special characters causing issues

4. **Data Volume Issues**
   - Too many vulnerabilities to process
   - Backend timeout while aggregating data
   - Database query optimization problems

5. **Regional/Environment Specific**
   - All your clusters appear to be in staging/test environments
   - Test environment APIs might have different stability SLAs
   - Regional endpoint (au.xdr.trendmicro.com) might be affected

## Code Improvements Applied

### Enhanced Error Logging

Updated `/go/src/get_container_vulnerabilities.go` to:

1. **Read response body on errors** - previously skipped for 500 errors
2. **Parse error messages** - extract detailed error info from JSON response
3. **Display error details** - show first 500 chars of error response
4. **Structured logging** - OpenTelemetry compliant error logs

### What Changed

**Before:**
```go
if resp.StatusCode != http.StatusOK {
    return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
}
```

**After:**
```go
body, err := io.ReadAll(resp.Body)
// ... error handling ...

if resp.StatusCode != http.StatusOK {
    // Parse error details from response body
    errorMsg := fmt.Sprintf("API returned status %d", resp.StatusCode)
    
    if len(body) > 0 {
        // Try to extract error message from JSON
        var errorResponse map[string]interface{}
        if err := json.Unmarshal(body, &errorResponse); err == nil {
            if msg, ok := errorResponse["error"].(map[string]interface{}); ok {
                if message, ok := msg["message"].(string); ok {
                    errorMsg = fmt.Sprintf("API returned status %d: %s", resp.StatusCode, message)
                }
            }
        }
        
        // Show response body for debugging
        fmt.Printf("Response body: %s\n", string(body))
    }
    
    return nil, fmt.Errorf("%s", errorMsg)
}
```

## Next Steps

### 1. Run with Enhanced Error Reporting

The binary has been rebuilt with better error handling. Run again:

```bash
./go/bin/get_container_vulnerabilities
```

**Expected Outcome:** 
You'll now see the actual error message from the API, not just "status 500"

### 2. Test API Directly with curl

Use the same base URL and token from Pass that your get_* scripts use:

```bash
# Use your environment (e.g. production or production_au)
ENV=production
TOKEN=$(pass show TrendMicro/$ENV/api_token | head -1)
BASE_URL=$(pass show TrendMicro/$ENV/api_base_url | head -1)

# Test connectivity (kubernetesClusters)
curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET \
  "${BASE_URL}/v3.0/containerSecurity/kubernetesClusters?top=1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json"

# Test Vulnerabilities API
curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET \
  "${BASE_URL}/v3.0/containerSecurity/vulnerabilities?top=5" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json"
```

If the get_* scripts work, these curl calls should return HTTP 200.

### 3. Try Simplified Query

Create a test that removes query parameters:

```bash
# Minimal query - no filters, no ordering
TOKEN=$(pass show TrendMicro/quality_test/api_token | head -1)

curl -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/json" \
     "https://api.au.xdr.trendmicro.com/beta/containerSecurity/vulnerabilities?top=1"
```

### 4. Check Different Environment

Try a production environment instead of quality_test:

```bash
./go/bin/get_container_vulnerabilities --environment production
```

### 5. Test Clusters Endpoint

Verify basic API connectivity by testing the clusters endpoint (which is working):

```bash
TOKEN=$(pass show TrendMicro/quality_test/api_token | head -1)

curl -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/json" \
     "https://api.au.xdr.trendmicro.com/beta/containerSecurity/kubernetesClusters"
```

### 6. Contact Trend Micro Support

If the API continues to return 500 errors, gather:

1. **Error details** from the enhanced logging output
2. **Timestamp** of the requests
3. **Environment** being accessed (quality_test)
4. **API endpoint** failing: `/beta/containerSecurity/vulnerabilities`
5. **Cluster IDs** being queried

Then open a support ticket with Trend Micro explaining:
- Beta API returning 500 for container vulnerabilities
- Authentication working (can fetch clusters successfully)
- Request for API status or known issues

## Workarounds

### Use Alternative Endpoints

If available, try:
- Non-beta endpoints (if they exist)
- Different API versions
- Portal UI to verify if data is accessible there

### Retry Logic

Add exponential backoff retry logic:

```go
maxRetries := 3
for attempt := 0; attempt < maxRetries; attempt++ {
    resp, err := client.Do(req)
    if err == nil && resp.StatusCode == http.StatusOK {
        break
    }
    
    if resp.StatusCode == 500 {
        waitTime := time.Duration(math.Pow(2, float64(attempt))) * time.Second
        time.Sleep(waitTime)
        continue
    }
    
    break
}
```

### Use Cached Data

If you have historical vulnerability data, use it temporarily until the API is restored.

## Prevention

### Monitoring

Add health checks:

```bash
# Add to cron for monitoring
*/15 * * * * /path/to/check_api_health.sh
```

### Alerting

Create alerts for:
- Consecutive API failures
- Sustained 500 error rates
- Changes in API response times

## Additional Resources

- [CONTAINER_SECURITY.md](./CONTAINER_SECURITY.md) - Container security documentation
- Trend Micro Vision One API Documentation
- Trend Micro Support Portal

## Summary

**The Issue:** Trend Micro API server error, not your token/permissions

**What Works:** 
- ✅ Authentication (token is valid)
- ✅ Authorization (permissions are correct)
- ✅ Cluster listing endpoint works

**What Doesn't Work:**
- ❌ Container vulnerabilities endpoint (`/beta/containerSecurity/vulnerabilities`)

**Next Action:** Run the updated binary to see detailed error messages from the API
