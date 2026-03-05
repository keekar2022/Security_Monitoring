# Container Vulnerability Script - CSV Loading Update

## Overview
The `get_container_vulnerabilities.py` script has been updated to properly parse and handle vulnerability data from both:
1. **Trend Micro Vision One API** (original functionality)
2. **CSV export files** (NEW - for analyzing exported vulnerability reports)

## What Was Fixed

### Data Field Mapping Issues
The script previously expected specific API field names (`cvssRecords`, `riskLevel`, etc.) but Trend Micro's CSV exports use different column names:

| Attribute | CSV Column | API Field | Status |
|-----------|-----------|-----------|--------|
| CVE ID | `CVE` | `name` | ✅ Fixed |
| Severity | `CVSS Severity` | `cvssRecords[0].severity` | ✅ Fixed |
| Registry | `Registry` or `Image Repository` | `registry` | ✅ Fixed |
| Cluster | `cluster` | N/A | ✅ Added |
| Image | `Image Name` | Various | ✅ Fixed |

### Specific Fixes
1. **Updated severity field extraction** to check multiple possible field names:
   - CSV exports use `CVSS Severity` 
   - API responses use `cvssRecords[0].severity` or `riskLevel`
   - Now handles all formats with proper normalization

2. **Fixed CVE/vulnerability identification**:
   - CSV: `CVE` column
   - API: `name` field
   - Script now checks both

3. **Enhanced cluster grouping for CSV data**:
   - Automatically detects `cluster` column in CSV
   - Groups vulnerabilities by cluster name
   - Maps to configured cluster IDs

4. **Fixed encoding issues**:
   - Uses `utf-8-sig` to handle BOM (Byte Order Mark) in CSV exports

## Usage

### Option 1: Load from CSV Export
```bash
./get_container_vulnerabilities.py \
  --csv-input /path/to/export.csv \
  --summary-only
```

### Option 2: Traditional API Mode (Default)
```bash
./get_container_vulnerabilities.py
```

### Combined Examples

**Generate summary only from CSV:**
```bash
python3 get_container_vulnerabilities.py \
  --csv-input TrendVisionOne_ContainerProtection_KubernetesVulnerabilities_20260129060221.csv \
  --summary-only \
  --quiet
```

**Generate reports and CSV output:**
```bash
python3 get_container_vulnerabilities.py \
  --csv-input export.csv \
  --output vulnerability_analysis.txt \
  --csv-output analysis_summary.csv
```

**Generate OTel logs from CSV:**
```bash
python3 get_container_vulnerabilities.py \
  --csv-input export.csv \
  --otel-output metrics.jsonl
```

## Data Verification

From your test CSV (7020 vulnerabilities):
- **Total:** 7020 ✓
- **Critical:** 17 ✓
- **High:** 1244 ✓
- **Medium:** 3782 ✓
- **Low:** 70 ✓
- **Negligible:** 1907 ✓

By Cluster:
- **AMS_EKS_SSA_AU_Stage:** 6656 vulnerabilities ✓
- **AMS_EKS_Stage_01:** 364 vulnerabilities ✓

## Output Files Generated

When using CSV input mode, the script generates:

1. **container_vulnerability_summary.csv** - Tabular summary with:
   - Timestamp
   - Environment
   - Business Name & Region
   - Group and Cluster IDs
   - Vulnerability counts by severity
   - Risk scores

2. **container_vulnerability_metrics.jsonl** - OpenTelemetry format for Grafana/Loki:
   - One JSON object per line
   - Machine-parseable metrics
   - Suitable for time-series visualization

3. **container_vulnerability_report.txt** - Detailed text report (optional)

## New Command-Line Options

### `--csv-input <file>`
Load vulnerabilities from a CSV export file instead of querying the API.
- Useful for: Analyzing historical data, batch processing, testing
- Format: Trend Micro Vision One CSV export
- Encoding: UTF-8 with BOM support

Example:
```bash
python3 get_container_vulnerabilities.py --csv-input vulnerabilities.csv
```

## Backward Compatibility

All existing scripts and workflows remain fully functional:
- API mode works exactly as before when `--csv-input` is not specified
- All original command-line options still available
- Output formats unchanged

## Technical Details

### Field Mapping Logic
```python
# Severity extraction (in order of priority)
1. Check CSV 'CVSS Severity' column
2. Check API 'cvssRecords[0].severity'
3. Check API 'riskLevel'
4. Check generic 'severity' field
5. Default to 'unknown'
```

### Cluster Grouping
- Automatically detects cluster information in CSV
- Groups vulnerabilities by matching cluster names
- Handles cases where cluster info is missing
- Maps to Kubernetes cluster IDs from configuration

### CSV Encoding
- Reads with UTF-8 Signature (utf-8-sig)
- Handles Excel-generated CSVs with BOM
- Fallback to standard UTF-8 if needed

## Testing

Test data was verified with the provided CSV:
```
TrendVisionOne_ContainerProtection_KubernetesVulnerabilities_20260129060221.csv
```

All metrics match the source data exactly, confirming:
- ✅ Correct severity parsing
- ✅ Proper cluster grouping
- ✅ Accurate totals and breakdowns
- ✅ Valid data transformations

## Support

For issues or questions:
1. Check that CSV format matches Trend Micro export (check column names)
2. Verify encoding is UTF-8 with potential BOM
3. Use `--verbose` (remove `--quiet`) for detailed processing logs
4. Review generated files for data accuracy
