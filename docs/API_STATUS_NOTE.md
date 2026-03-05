# Trend Micro Vision One API Issue - January 29, 2026

## Current Status
**The Trend Micro Vision One Container Security API is returning HTTP 500 errors.**

### Error Details
```
HTTP 500 Internal Server Error
{"error":{"code":"Internal Server Error","message":"Failed to process the API. Please contact Trend Micro Support."}}
```

### Affected Endpoints
- `/beta/containerSecurity/vulnerabilities` (with or without TMV1-Filter header)
- Both cluster-filtered and unfiltered queries fail

### Workaround
**Use CSV export mode instead of API mode:**

```bash
# CSV Mode (WORKING ✅)
python3 get_container_vulnerabilities.py \
  --csv-input /path/to/export.csv \
  --summary-only

# API Mode (BROKEN ❌ - HTTP 500)
python3 get_container_vulnerabilities.py \
  --environment quality_test \
  --summary-only
```

### Testing Timeline
- **06:17:10 UTC** - CSV mode: ✅ 7,020 vulnerabilities loaded successfully
- **06:23:22 UTC** - API mode: ❌ HTTP 500 error, 0 vulnerabilities
- **06:25+ UTC** - API still returning 500 errors

### Verification
The data definitely exists (proven by CSV export), but the API backend is temporarily unavailable.

### Recommended Action
1. **Short term**: Use CSV export mode (`--csv-input`) for vulnerability analysis
2. **Long term**: Contact Trend Micro Support about the API 500 errors
3. **Alternative**: Monitor API status page at https://api.xdr.trendmicro.com/

### CSV Mode Features
✅ Full data parsing from Trend Micro CSV exports
✅ Proper severity classification (CVSS Severity field)  
✅ Cluster grouping (cluster column)
✅ All output formats (reports, OTel logs, CSV summary)
✅ No API credentials required

## Implementation Notes

### Fallback Logic Added
The script now includes a fallback mechanism that:
1. Attempts the clustered API query with TMV1-Filter header
2. Falls back to unfiltered query + client-side filtering on HTTP 500
3. Supports multiple cluster ID field names in API response
4. Returns 0 vulnerabilities if API continues to fail (graceful degradation)

### For Developers
When API is restored, verify:
- Response status code is 200
- Items array contains vulnerability objects with `clusterId` field
- Pagination with `nextLink` works correctly

---

**Last Updated:** 2026-01-29 06:25 UTC  
**Status:** ⚠️ API Degraded - Use CSV mode as workaround
