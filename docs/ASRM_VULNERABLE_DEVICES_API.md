# ASRM Vulnerable Devices API – Information Available

This document describes what information you can retrieve from **`https://api.au.xdr.trendmicro.com/v3.0/asrm/vulnerableDevices`** using tokens stored in **pass**.

> **Note:** The standalone Go tool `asrm_vulnerable_devices` was removed. Endpoint vulnerability data for the viewer is produced by **`get_endpoint_vulnerabilities`** (which uses device + per-device CVE APIs). This doc remains for API reference.

---

## Endpoint

| Item | Value |
|------|--------|
| **URL** | `https://api.au.xdr.trendmicro.com/v3.0/asrm/vulnerableDevices` |
| **Method** | GET |
| **Auth** | Bearer token (from pass: `TrendMicro/quality_test/api_token` or `TrendMicro/production_au/api_token`) |
| **Base URL source** | `api.au.xdr.trendmicro.com` is used for **quality_test** and **production_au** in this project |

---

## Request behavior

- **Without query parameters:** Returns **200 OK** with a full (paginated) list of vulnerable devices.
- **With `?top=N`:** This endpoint may return **400 Bad Request** (“Unable to retrieve vulnerabilities information…”). Prefer calling without `top` and use `nextLink` for paging if needed.

---

## Response structure (top-level)

| Key | Type | Description |
|-----|------|-------------|
| **count** | number | Number of items in this page. |
| **totalCount** | number | Total number of vulnerable devices. |
| **items** | array | List of vulnerable device objects (see below). |
| **nextLink** | string (optional) | URL for the next page of results (pagination). |

---

## Information per device (`items[]`)

Each element in **items** is a vulnerable device with at least:

| Field | Type | Description |
|-------|------|-------------|
| **id** | string | Device identifier. |
| **deviceName** | string | Display name of the device. |
| **ip** | string | IP address of the device. |
| **criticality** | string | e.g. `"high"`, `"medium"`, `"low"`. |
| **lastScannedDateTime** | string | When the device was last scanned. |
| **cveRecords** | array | List of CVE records for this device (see below). |

---

## Information per CVE (`cveRecords[]`)

Each CVE record includes:

| Field | Type | Description |
|-------|------|-------------|
| **id** | string | CVE ID (e.g. `"CVE-2025-40778"`). |
| **cvssScore** | number | CVSS score (e.g. 8.6). |
| **eventRiskLevel** | string | Risk level for the event. |
| **globalExploitActivityLevel** | string | e.g. `"medium"`. |
| **exploitAttemptCount** | number | Count of exploit attempts. |
| **affectedComponents** | array of strings | Affected package/component names (e.g. `bind-utils`, `python3-bind`). |
| **mitigationOption** | object | Remediation information (see below). |

### Mitigation information (`mitigationOption`)

- **linuxRemediations** (array): Each element can include:
  - **packageName** – Package to update (e.g. `"bind"`).
  - **minimumPatchedPackageVersion** – Version that fixes the CVE.
  - **productDistribution** – OS/distro (e.g. `"Amazon Linux 2023"`, `"Red Hat Enterprise Linux 10"`).
  - **releaseDate** – When the fix was released.
  - **securityAdvisoryId** – Advisory ID (e.g. `"ALAS2023-2025-1255"`, `"RHSA-2025:19912"`).
  - **securityAdvisoryLink** – URL to the advisory (e.g. AWS ALAS, Red Hat errata).

---

## How to call it using pass

### 1. Using the project’s Go tool

The standalone `asrm_vulnerable_devices` Go binary was removed. To get endpoint vulnerability data for the viewer, use **`get_endpoint_vulnerabilities`** instead. To call this API directly (e.g. for debugging), use curl as in the next section.

### 2. Using curl and pass

```bash
# Quality & Test (AU)
TOKEN=$(pass TrendMicro/quality_test/api_token | head -1)
curl -s -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/json" \
     "https://api.au.xdr.trendmicro.com/v3.0/asrm/vulnerableDevices"

# Production AU
TOKEN=$(pass TrendMicro/production_au/api_token | head -1)
curl -s -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/json" \
     "https://api.au.xdr.trendmicro.com/v3.0/asrm/vulnerableDevices"
```

---

## Summary of what you can get

Using **`https://api.au.xdr.trendmicro.com/v3.0/asrm/vulnerableDevices`** with tokens from pass you can obtain:

1. **List of vulnerable devices** – id, name, IP, criticality, last scan time.
2. **Per-device CVE list** – CVE ID, CVSS score, risk levels, exploit attempt count.
3. **Affected components** – Package/component names (e.g. bind, python3-bind).
4. **Remediation data** – Patched package versions, product/distro, advisory IDs and links (e.g. AWS ALAS, Red Hat RHSA).

This is **endpoint/ASRM vulnerability data** (devices with CVEs and mitigations), not container or Kubernetes vulnerability data.

---

## References

- Trend Vision One Automation Center (API reference): https://automation.trendmicro.com/xdr/api-v3/
- Project config for AU base URL: `config/deployment_config.json` (environments `quality_test`, `production_au`).
- Token storage: pass paths `TrendMicro/quality_test/api_token`, `TrendMicro/production_au/api_token`.
