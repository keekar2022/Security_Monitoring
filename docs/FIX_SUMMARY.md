# Fix Summary: Container Vulnerability Script - CSV Data Loading

## Problem Statement
The `get_container_vulnerabilities.py` script was not properly parsing vulnerability data from Trend Micro CSV exports. The CSV data structure differed from the API response structure, causing data to be misread or skipped entirely.

## Root Causes Identified

1. **Field Name Mismatches**
   - CSV uses `CVSS Severity`, API uses `cvssRecords[0].severity` or `riskLevel`
   - CSV uses `CVE` column, API uses `name` field
   - Script was hard-coded to only check API field names

2. **Missing Cluster Information Handling**
   - CSV contains a `cluster` column that wasn't being used
   - Cluster grouping wasn't working for CSV data

3. **Encoding Issues**
   - CSV files from Trend Micro include BOM (Byte Order Mark)
   - Standard UTF-8 decoding was failing silently

4. **No CSV Input Support**
   - Script only had API mode
   - No way to analyze exported CSV files directly

## Changes Made

### 1. **Updated Field Extraction Logic** 
**Files:** `get_container_vulnerabilities.py`

**Methods Updated:**
- `analyze_vulnerabilities_per_cluster()` - Now checks multiple field names for severity
- `analyze_vulnerabilities()` - Enhanced registry and field detection
- Added `load_vulnerabilities_from_csv()` - New method to load from CSV files

**Severity Field Resolution (Priority Order):**
```python
1. CSV 'CVSS Severity' column → ✅ Primary for CSV data
2. API 'cvssRecords[0].severity' → ✅ Primary for API data
3. API 'riskLevel' field → Fallback for API
4. Generic 'severity' field → Fallback
5. 'unknown' → Default if all fail
```

**Registry/Image Field Resolution:**
```python
1. 'Registry' (CSV column)
2. 'registry' (API field)
3. 'Image Repository' (CSV column)
4. 'Unknown' (default)
```

**CVE/Vulnerability Field Resolution:**
```python
1. 'CVE' (CSV column) ✅ Primary
2. 'name' (API field) ✅ Primary
3. 'Unknown' (default)
```

### 2. **Added CSV Loading Support**

**New Method:** `load_vulnerabilities_from_csv(csv_file, verbose=True)`

**Features:**
- Reads CSV files with UTF-8-BOM encoding (handles Excel exports)
- Returns list of vulnerability dictionaries
- Verbose output shows loaded count and field names
- Error handling for missing/invalid files

**Usage:**
```python
collector = ContainerVulnerabilityCollector(config, group_id, group_name)
vulnerabilities = collector.load_vulnerabilities_from_csv('/path/to/export.csv')
```

### 3. **Enhanced Cluster Grouping for CSV**

**CSV Cluster Detection:**
- Automatically finds `cluster` column in CSV
- Groups vulnerabilities by cluster name
- Maps to Kubernetes cluster IDs from configuration
- Handles missing cluster info gracefully

**Implementation in Main Flow:**
```python
if args.csv_input:
    # Load from CSV
    vulnerabilities = collector.load_vulnerabilities_from_csv(args.csv_input)
    
    # Auto-detect cluster column
    cluster_col = detect_cluster_column(sample_row)
    
    # Group by cluster
    if cluster_col:
        group_vulnerabilities_by_cluster(vulnerabilities, collector)
else:
    # Original API mode
    vulnerabilities = collector.fetch_vulnerabilities()
```

### 4. **Added Command-Line Option**

**New Argument:** `--csv-input <file>`

```bash
python3 get_container_vulnerabilities.py --csv-input vulnerabilities.csv
```

**Behaviors:**
- When CSV input is provided, automatically uses first environment
- Preserves all other command-line options
- Generates same output formats as API mode
- Backward compatible with existing scripts

### 5. **Fixed Encoding Issues**

**Change:** `encoding='utf-8'` → `encoding='utf-8-sig'`

**Impact:**
- ✅ Handles Byte Order Mark (BOM) in Excel-generated CSVs
- ✅ Properly reads first column (CVE) without corruption
- ✅ Fallback to standard UTF-8 if needed

## Testing & Validation

### Test Data
```
File: TrendVisionOne_ContainerProtection_KubernetesVulnerabilities_20260129060221.csv
Format: Trend Micro Vision One Container Security export
```

### Validation Results
✅ **All metrics match source data exactly:**

| Metric | Value | Status |
|--------|-------|--------|
| Total Vulnerabilities | 7020 | ✅ Correct |
| Critical | 17 | ✅ Correct |
| High | 1244 | ✅ Correct |
| Medium | 3782 | ✅ Correct |
| Low | 70 | ✅ Correct |
| Negligible | 1907 | ✅ Correct |
| **Unique CVEs** | **3416** | ✅ Correct |

### Cluster Breakdown
| Cluster | Vulnerabilities | Status |
|---------|-----------------|--------|
| AMS_EKS_SSA_AU_Stage | 6656 | ✅ Correct |
| AMS_EKS_Stage_01 | 364 | ✅ Correct |

## Usage Examples

### Basic CSV Analysis
```bash
python3 get_container_vulnerabilities.py \
  --csv-input export.csv \
  --summary-only
```

### Generate Full Reports
```bash
python3 get_container_vulnerabilities.py \
  --csv-input export.csv \
  --output analysis.txt \
  --csv-output summary.csv
```

### Generate OTel Metrics
```bash
python3 get_container_vulnerabilities.py \
  --csv-input export.csv \
  --otel-output metrics.jsonl
```

### Quiet Mode (for cron/automation)
```bash
python3 get_container_vulnerabilities.py \
  --csv-input export.csv \
  --quiet \
  --summary-only
```

## Output Files Generated

When using CSV input mode:

1. **container_vulnerability_summary.csv** - Tabular summary
   - Timestamp, Environment, Business, Region
   - Group/Cluster IDs and names
   - Counts by severity level
   - Risk scores

2. **container_vulnerability_metrics.jsonl** - OTel format
   - JSON Lines (one object per line)
   - Compatible with Grafana/Loki
   - Machine-parseable metrics

3. **container_vulnerability_report.txt** - Detailed report
   - Hierarchical cluster view
   - Statistical summaries
   - API endpoint details

## Backward Compatibility

✅ **Fully backward compatible**
- All existing API mode functionality unchanged
- Default behavior without `--csv-input` is identical to before
- All original command-line options work as expected
- No changes to output formats when using API mode

## Files Modified

1. **get_container_vulnerabilities.py**
   - Added CSV module import
   - Added `load_vulnerabilities_from_csv()` method
   - Updated `analyze_vulnerabilities_per_cluster()` for multi-field detection
   - Updated `analyze_vulnerabilities()` for multi-field detection
   - Added CSV input mode detection in main()
   - Added `--csv-input` command-line argument

2. **CSV_LOADING_UPDATE.md** (Documentation)
   - Usage guide
   - API vs CSV field mapping
   - Examples
   - Troubleshooting

3. **test_csv_parsing.py** (Test/Validation)
   - Comprehensive CSV parsing test
   - Validates all field extraction
   - Confirms cluster grouping
   - Verifies totals and breakdowns

## Key Improvements

| Area | Before | After |
|------|--------|-------|
| CSV Support | ❌ None | ✅ Full |
| Field Detection | ✅ API only | ✅ API + CSV |
| Encoding Handling | ⚠️ Basic | ✅ UTF-8-BOM aware |
| Error Reporting | ⚠️ Silent | ✅ Detailed verbose output |
| Cluster Grouping | ⚠️ API only | ✅ API + CSV |
| Data Validation | ⚠️ Manual | ✅ Automated test suite |

## Verification Commands

```bash
# Quick validation test
python3 test_csv_parsing.py

# Test full CSV mode
python3 get_container_vulnerabilities.py \
  --csv-input /path/to/export.csv \
  --summary-only \
  --quiet

# Compare with source CSV
head -5 /path/to/export.csv | awk -F',' '{print $1, $3, $10}'
```

## Notes

- Original API functionality remains unchanged and fully operational
- CSV mode does not require API credentials
- CSV data is processed in a single environment (first configured)
- All severity levels are properly normalized (case-insensitive)
- Cluster matching is name-based for CSV data
- Risk scores are calculated using: Critical=10, High=5, Medium=2, Low=1

---

**Last Updated:** 2026-01-29
**Status:** ✅ Implemented and tested
**Testing:** ✅ All validation checks passing
