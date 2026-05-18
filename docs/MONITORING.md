# Monitoring & Grafana

System health checks, OpenTelemetry-style logging, and Grafana/Loki integration. Replaces SYSTEM_HEALTH_MONITORING, QUICK_START_SYSTEM_HEALTH, GRAFANA_GUIDE, and archive OTEL/Grafana docs.

---

## API Server Health

The Go API server exposes:

- **GET /health** – Health and data status (e.g. last refresh, record counts).
- **GET /api/v1/stats** – Aggregated stats for container and endpoint data.

```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/stats
```

---

## Logging

Tools and the API server use structured (JSON) logs with OpenTelemetry-style attributes: `service.name`, `operation`, etc. Suitable for Loki or other log aggregators.

---

## Grafana & Loki

- **JSONL outputs** from the Go tools (`*_metrics.jsonl`) follow a consistent structure; you can define Loki labels (e.g. environment, aggregation level) and build dashboards.
- **Promtail**: Example config in `config/promtail-config.yaml`; point it at your JSONL or log directories and ship to Loki.
- **Dashboards**: Use `config/grafana-dashboard-container-security.json` as a starting point for container security metrics.
- **Streamlit (v1.0.11)**: **Keekar's Security Monitoring Dashboard** (`app.py`) displays Trend Micro JSONL and AEM Gov AU weekly legacy metrics (`data/server_vulnerabilities_legacy/`). Not a substitute for Grafana; see [AEM_GOVAU_LEGACY_DASHBOARD.md](AEM_GOVAU_LEGACY_DASHBOARD.md).

---

## Quick System Health Check

1. Start API server: `./go/bin/api-server --port 8080 --data-dir .` or `docker compose up -d`.
2. Run a scan: `./go/bin/get_container_vulnerabilities --environment production` (or use Docker).
3. Check health: `curl http://localhost:8080/health` and confirm data counts in the response.

---

[Back to INDEX](INDEX.md)
