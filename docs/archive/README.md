# Archived Documentation

This folder contains documentation files that have been superseded by consolidated guides.

**Date Archived:** January 21, 2026  
**Reason:** Documentation consolidation (reduced from 15 files to 6)  
**Maintained By:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## What Happened

The documentation was consolidated to improve navigation and reduce duplication. Related content was merged into comprehensive guides.

### Old Structure (15 files) → New Structure (6 files)

**Setup & Getting Started (3 files merged)**
- `API_KEY_SETUP_GUIDE.md` ➜ `../SETUP_GUIDE.md`
- `GETTING_STARTED.md` ➜ `../SETUP_GUIDE.md`
- Result: Single comprehensive setup guide

**Password Store (3 files merged)**
- `PASS_INTEGRATION.md` ➜ `../PASS_GUIDE.md`
- `PASS_QUICK_REFERENCE.md` ➜ `../PASS_GUIDE.md`
- `PASSWORD_STORE_GUIDE.md` ➜ `../PASS_GUIDE.md`
- Result: Complete Pass guide with all information

**Grafana/Loki (2 files merged)**
- `OTEL_GRAFANA_GUIDE.md` ➜ `../GRAFANA_GUIDE.md`
- `QUICK_START_GRAFANA.md` ➜ `../GRAFANA_GUIDE.md`
- Result: Single Grafana guide with quick start and details

**Configuration (1 file merged)**
- `MULTI_ENVIRONMENT_QUICK_GUIDE.md` ➜ `../CONFIGURATION.md`
- Result: Enhanced configuration guide

**Removed (3 files)**
- `DOCUMENTATION_UPDATE_SUMMARY.md` - Tracking file (no longer needed)
- `AWS_EFFORT_ESTIMATION.md` - Optional reference
- `AWS_EXECUTIVE_SUMMARY.md` - Optional reference
- `ENDPOINT_API_FINDINGS.md` - Notes file

---

## Current Active Documentation

See parent directory (`../`) for the new streamlined documentation:

1. **`SETUP_GUIDE.md`** - Complete setup from scratch
2. **`PASS_GUIDE.md`** - Password Store complete guide
3. **`GRAFANA_GUIDE.md`** - Grafana/Loki setup
4. **`CONTAINER_SECURITY.md`** - Vulnerability scanning
5. **`CONFIGURATION.md`** - Configuration reference
6. **`BEST_PRACTICES.md`** - Best practices

---

## Should I Use These Archived Files?

**Short answer:** No, use the new consolidated guides.

**Why these are archived:**
- Content is duplicated or superseded
- Better organization in new guides
- Easier to find information in consolidated format

**When you might need these:**
- Historical reference
- Comparing old vs new structure
- Recovery if something was accidentally removed

---

## File Inventory

### Merged into SETUP_GUIDE.md
- `API_KEY_SETUP_GUIDE.md` (14KB) - Visual API key setup walkthrough
- `GETTING_STARTED.md` (6.7KB) - Quick start guide

### Merged into PASS_GUIDE.md
- `PASS_INTEGRATION.md` (15KB) - Pass integration details
- `PASS_QUICK_REFERENCE.md` (3.2KB) - Command reference
- `PASSWORD_STORE_GUIDE.md` (13KB) - Pass setup guide

### Merged into GRAFANA_GUIDE.md
- `OTEL_GRAFANA_GUIDE.md` (28KB) - Complete Grafana integration
- `QUICK_START_GRAFANA.md` (8.7KB) - 10-minute setup

### Merged into CONFIGURATION.md
- `MULTI_ENVIRONMENT_QUICK_GUIDE.md` (8.1KB) - Multi-environment setup

### Reference/Notes (Archived)
- `DOCUMENTATION_UPDATE_SUMMARY.md` (13KB) - Update tracking
- `AWS_EFFORT_ESTIMATION.md` (19KB) - AWS migration estimate
- `AWS_EXECUTIVE_SUMMARY.md` (14KB) - AWS executive summary
- `ENDPOINT_API_FINDINGS.md` (7.3KB) - Endpoint API notes

---

## Migration Guide

If you have bookmarks or references to old files:

| Old File | New Location | Section |
|----------|--------------|---------|
| `API_KEY_SETUP_GUIDE.md` | `SETUP_GUIDE.md` | Step 3-4 |
| `GETTING_STARTED.md` | `SETUP_GUIDE.md` | Full guide |
| `PASS_INTEGRATION.md` | `PASS_GUIDE.md` | Why Use Pass, Integration |
| `PASS_QUICK_REFERENCE.md` | `PASS_GUIDE.md` | Command Reference |
| `PASSWORD_STORE_GUIDE.md` | `PASS_GUIDE.md` | Installation, Setup |
| `OTEL_GRAFANA_GUIDE.md` | `GRAFANA_GUIDE.md` | Detailed Setup |
| `QUICK_START_GRAFANA.md` | `GRAFANA_GUIDE.md` | Quick Start |
| `MULTI_ENVIRONMENT_QUICK_GUIDE.md` | `CONFIGURATION.md` | Multi-Environment |

---

## Cleanup

These files can be deleted if no longer needed:

```bash
# Remove entire archive (not recommended immediately)
rm -rf /path/to/docs/archive/

# Keep for 30 days, then consider removal
```

**Recommendation:** Keep archive for 30-90 days, then remove if no issues found.

---

**Questions?** See `../README.md` in parent directory or main project `README.md`.

---

**Last Updated:** January 21, 2026
