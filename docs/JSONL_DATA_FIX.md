# JSONL Data Population Fix

## Problem Summary

The `container_vulnerability_metrics.jsonl` file was missing critical data that was present in the CSV file:

1. ❌ **Missing Cluster ID** - No `cluster.id` attribute
2. ❌ **Incomplete Data** - Only had 291 group-level entries, missing individual cluster records
3. ❌ **CSV had 217 cluster-level records** - JSONL only had group aggregations

## Root Cause

The Go code (`get_container_vulnerabilities.go`) was only generating **group-level** JSONL entries but not **cluster-level** entries:

```go
// OLD CODE - Only group-level entries
for _, groupResult := range envResults.GroupResults {
    stats := analyzeVulnerabilities(groupResult.Vulns)
    entry := map[string]interface{}{
        "Attributes": map[string]interface{}{
            "group.id": groupResult.GroupID,
            "group.name": groupResult.GroupName,
            // ❌ Missing cluster.id and cluster.name
        }
    }
}
```

## Fixes Applied

### 1. Updated Go Code (`get_container_vulnerabilities.go`)

**Location:** Lines 645-700

**Changes:**
- ✅ Added cluster-level iteration
- ✅ Added `cluster.id` attribute
- ✅ Added `cluster.name` attribute
- ✅ Filter vulnerabilities per cluster
- ✅ Generate individual cluster entries (not just group aggregations)

**New Code Structure:**
```go
// NEW CODE - Cluster-level entries
for _, cluster := range groupResult.Clusters {
    // Filter vulnerabilities for this specific cluster
    var clusterVulns []*ContainerVulnerability
    for _, vuln := range groupResult.Vulns {
        if vuln.ClusterID == cluster.ID {
            clusterVulns = append(clusterVulns, vuln)
        }
    }
    
    clusterEntry := map[string]interface{}{
        "Attributes": map[string]interface{}{
            "cluster.id": cluster.ID,        // ✅ Added
            "cluster.name": cluster.Name,    // ✅ Added
            "group.id": groupResult.GroupID,
            "group.name": groupResult.GroupName,
            "vulnerability.total": stats.Total,
            "vulnerability.severity.critical": stats.Critical,
            "vulnerability.severity.high": stats.High,
            "vulnerability.severity.medium": stats.Medium,
            "vulnerability.severity.low": stats.Low,
            "vulnerability.severity.unknown": stats.Unknown,
            "vulnerability.risk_score": stats.RiskScore,
            "event.dataset": "container.vulnerability.cluster", // ✅ Changed from "group"
            "aggregation.level": "cluster",  // ✅ Changed from "group"
        }
    }
}
```

### 2. Created CSV-to-JSONL Converter (`convert_csv_to_jsonl.py`)

**Purpose:** Backfill existing CSV data into JSONL format

**Features:**
- Reads `container_vulnerability_summary.csv`
- Converts to OpenTelemetry-compliant JSONL format
- Maps business names to account IDs
- Maps regions to API endpoints
- Preserves all timestamp and metric data

**Usage:**
```bash
cd /Users/mkesharw/Documents/Integration-API-Dev
python3 convert_csv_to_jsonl.py
```

### 3. Rebuilt Go Binary

```bash
cd go
go build -o bin/get_container_vulnerabilities src/get_container_vulnerabilities.go
```

## Results

### Before Fix

```json
{
  "Attributes": {
    "group.id": "...",
    "group.name": "Ungrouped",
    // ❌ No cluster.id
    // ❌ No cluster.name
    "vulnerability.total": 253,
    "event.dataset": "container.vulnerability.group"
  }
}
```

**Records:** 291 group-level entries only

### After Fix

```json
{
  "Attributes": {
    "cluster.id": "AMS_EKS_Stage_01-38Sc5cvwieGJs9cus2sGVU7901c",  // ✅ Added
    "cluster.name": "AMS_EKS_Stage_01",                            // ✅ Added
    "group.id": "00000000-0000-0000-0000-000000000001",
    "group.name": "Ungrouped",
    "vulnerability.total": 253,
    "vulnerability.severity.critical": 2,
    "vulnerability.severity.high": 61,
    "vulnerability.severity.medium": 123,
    "vulnerability.severity.low": 23,
    "vulnerability.severity.unknown": 0,
    "vulnerability.risk_score": 594,
    "event.dataset": "container.vulnerability.cluster",            // ✅ Changed
    "aggregation.level": "cluster"                                 // ✅ Added
  }
}
```

**Records:** 217 cluster-level entries (matches CSV)

## Verification

### Check Record Count
```bash
wc -l container_vulnerability_metrics.jsonl
# Output: 217 container_vulnerability_metrics.jsonl
```

### Verify Cluster ID Present
```bash
head -1 container_vulnerability_metrics.jsonl | jq '.Attributes | keys'
# Output includes: "cluster.id", "cluster.name"
```

### Check Data Integrity
```bash
head -1 container_vulnerability_metrics.jsonl | jq -r '.Attributes["cluster.id"], .Attributes["cluster.name"]'
# Output:
# AMS_EKS_Stage_01-38Sc5cvwieGJs9cus2sGVU7901c
# AMS_EKS_Stage_01
```

## Impact on Visualization

The JSONL viewer (`jsonl_viewer.html`) now shows:

### Chart View
- ✅ **Individual cluster lines** - Each cluster gets its own line on the graph
- ✅ **Cluster identification** - Can track specific clusters over time
- ✅ **Complete metrics** - All severity levels and risk scores per cluster

### Table View
- ✅ **Cluster ID column** - Full cluster identification
- ✅ **Per-cluster metrics** - Individual vulnerability counts
- ✅ **Complete data** - All 217 records visible

## Future Use

Going forward, when you run:

```bash
./go/bin/get_container_vulnerabilities
```

The tool will now automatically:
1. ✅ Generate cluster-level JSONL entries
2. ✅ Include `cluster.id` and `cluster.name` attributes
3. ✅ Match CSV structure exactly
4. ✅ Support proper visualization in charts

## Files Modified

1. **`go/src/get_container_vulnerabilities.go`** - Fixed OTel logs generation
2. **`go/bin/get_container_vulnerabilities`** - Rebuilt binary
3. **`container_vulnerability_metrics.jsonl`** - Populated with complete data
4. **`convert_csv_to_jsonl.py`** - New conversion utility (for backfill)

## Testing

Test the visualization:

```bash
# Open browser to
http://localhost:8080/jsonl_viewer.html

# Switch to "Chart View" tab
# You should now see individual lines for:
# - AMS_EKS_Stage_01
# - AMS_EKS_Zubin_China
# - AMS_EKS_Zubin_Korea_1
# - AMS_EKS_Zubin_Enterprise
# - AMS_EKS_Zubin_Basic
# - Zubin_AU_PRD
# - Zubin_AU_STG
# ... and all other clusters
```

## Summary

✅ **Problem:** JSONL missing cluster-level data and cluster IDs  
✅ **Root Cause:** Go code only generated group-level entries  
✅ **Fix:** Updated Go code to generate cluster-level entries with cluster IDs  
✅ **Backfill:** Created Python script to populate from CSV  
✅ **Result:** Complete JSONL data with 217 cluster records matching CSV  
✅ **Benefit:** Charts now show individual cluster trends over time
