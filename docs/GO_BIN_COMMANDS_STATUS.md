# Go bin Commands – Execution Status by Environment

Summary of running each binary in `./go/bin/` and which environments work or fail. Run from project root: `cd /Users/mkesharw/Documents/Integration-API-Dev`.

**Current tools (viewer data):** `get_container_vulnerabilities`, `get_endpoint_stats`, `get_endpoint_vulnerabilities`, `api-server`  
**Environments tested:** `quality_test`, `production`, `production_au`  
**Date:** 2026-02-09

---

## Summary table

| Binary | quality_test | production | production_au | Notes |
|--------|--------------|------------|---------------|--------|
| **get_container_vulnerabilities** | ✅ Runs | — | — | Runs; long runtime (many clusters/vulns); not run to completion |
| **get_endpoint_stats** | ❌ | — | ❌ | Exit 0 but "Failed to fetch OAT detections" HTTP 400; 0 envs scanned |
| **get_endpoint_vulnerabilities** | ❌ | — | — | Exit 1; "UNABLE TO FETCH DEVICE DATA" (permissions / device APIs 404) |
| **api-server** | N/A | N/A | N/A | ✅ Starts; /health returns 200 |

---

## 1. get_container_vulnerabilities

**Usage:** `./go/bin/get_container_vulnerabilities [--environment <env>] [--quiet] [--no-otel] [--no-csv]`

| Environment | Result | Details |
|-------------|--------|---------|
| quality_test | ✅ Runs | Starts and runs; long runtime (many clusters/vulnerabilities). Run interrupted after 25s; did not run to completion in test. |

**Conclusion:** Command runs for quality_test. Full run takes a long time. Other envs not exercised.

---

## 2. get_endpoint_stats

**Usage:** `./go/bin/get_endpoint_stats [--environment <env>] [--quiet] [--summary-only]`

| Environment | Result | Details |
|-------------|--------|---------|
| quality_test | ❌ | Exit 0. "Failed to fetch OAT detections" HTTP 400. environments_scanned=0. |
| production_au | ❌ | Same: HTTP 400 on OAT detections, 0 envs scanned. |

**Conclusion:** Fails with HTTP 400 on `/v3.0/oat/detections` for quality_test and production_au. Likely request format or required query params.

---

## 3. get_endpoint_vulnerabilities

**Usage:** `./go/bin/get_endpoint_vulnerabilities [--environment <env>] [--quiet]`

| Environment | Result | Details |
|-------------|--------|---------|
| quality_test | ❌ | Exit 1. "UNABLE TO FETCH DEVICE DATA" – device endpoints (v3.0/asrm/devices, v3.0/riskInsights/devices, v3.0/eiqs/endpoints) return 404; no devices to scan. |

**Conclusion:** Not working for quality_test; requires permissions or different endpoints for device/vulnerability data.

---

## 4. api-server

**Usage:** `./go/bin/api-server [--port <port>]`

| Test | Result | Details |
|------|--------|---------|
| Start + /health | ✅ | Server starts; GET /health returns 200 and JSON with status "healthy". |

**Conclusion:** Server runs and health check works. No environment flag; uses local data directory.

---

## Recommendations

1. **get_endpoint_stats** – Investigate why `/v3.0/oat/detections` returns 400 (query params, headers, or API change).
2. **get_endpoint_vulnerabilities** – Resolve device API 404s (permissions or switch to supported v3.0 device endpoints).
3. **get_container_vulnerabilities** – Allow long run or add options to limit scope (e.g. by group) for faster checks.

---

## How to re-run

From project root:

```bash
# Single env
./go/bin/get_container_vulnerabilities --environment quality_test --quiet
./go/bin/get_endpoint_stats --environment quality_test --quiet --summary-only
./go/bin/get_endpoint_vulnerabilities --environment quality_test --quiet

# api-server (then curl http://localhost:8080/health)
./go/bin/api-server --port 8080
```

Ensure `config/deployment_config.json` (or pass vault) has credentials for the environment used.
