# Migration & Go Implementation

Go implementation, language migration, and conversion notes. Replaces GO_MIGRATION_GUIDE, LANGUAGE_MIGRATION_GUIDE, CONVERSION_SUMMARY, and MIGRATION_COMPLETE.

---

## Go as Primary Implementation

The project uses **Go** for production tools and the API server:

- **API server**: `go/cmd/api-server/main.go` – serves JSONL metrics over HTTP.
- **CLI tools**: `get_container_vulnerabilities`, `get_endpoint_stats`, `get_endpoint_vulnerabilities` in `go/src/`.
- **Config**: Shared `go/lib/config_loader.go`; reads from `config/` and optional Pass.

Build and run:

```bash
cd go && make build
./bin/api-server --port 8080 --data-dir ..
./bin/get_container_vulnerabilities --environment production
```

---

## Language Migration (Python → Go)

- Logic and options mirror the original Python scripts; config (deployment_config, environments, api_endpoints) is shared.
- Credentials: Pass (preferred) or `config/deployment_config.json`; set `USE_PASS` or use default detection.
- Output paths and formats (CSV, TXT, JSONL) match the previous design for compatibility.

---

## Conversion Summary

- Container and endpoint tools are implemented in Go; Python/Node/Rust references in docs may remain for historical context.
- Cursor rules (observability, OWASP, markdown location, etc.) apply to all new code.
- Docker image includes the API server and CLI tools; use [QUICK_START_GUIDE.md](QUICK_START_GUIDE.md) and README for Docker.

---

[Back to INDEX](INDEX.md)
