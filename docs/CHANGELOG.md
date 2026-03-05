# Changelog & Fixes

Summary of changes, fixes, and implementation notes. Replaces WHATS_NEW, FIX_SUMMARY, VIEWER_DATA_DISPLAY_FIX, JSONL_DATA_FIX, CSV_LOADING_UPDATE, GO_BIN_COMMANDS_STATUS, and IMPLEMENTATION_SUMMARY.

---

## Recent Highlights

- **Go implementation**: API server and CLI tools (container vulns, endpoint inventory, endpoint vulns) are the primary implementation. Python/Node/Rust references may remain in docs for context.
- **Docker**: Image with in-image pass store; `export-pass-for-docker.sh` to bake tokens; sync scripts for Mac/Windows.
- **Pass & tokens**: Single-line token storage enforced to avoid HTTP 401; helper scripts `update-pass-credential.sh` and `verify_pass_tokens.sh`.
- **Docs**: Consolidated into fewer files (INDEX, QUICK_START_GUIDE, CONFIGURATION, PASS_AND_CREDENTIALS, FEATURES, API_REFERENCE, MONITORING, MIGRATION, BEST_PRACTICES, TROUBLESHOOTING, CHANGELOG).

---

## Fixes (Summarized)

- **Viewer data display**: Aligned with JSONL structure and API responses.
- **JSONL data**: Correct parsing and field names for Grafana/consumers.
- **CSV loading**: Consistent headers and encoding.
- **HTTP 500 handling**: Improved error logging and response body capture for container vulnerability API.
- **Go binaries**: Built via `go/Makefile`; binaries in `go/bin/`; Docker image includes all CLI tools and pass helpers.

---

## Version History

- **6.x** – Go-based platform, Docker, consolidated docs.
- **5.x** – Multi-language support, Cursor rules.
- **4.x** – OpenTelemetry, Grafana/Loki, container vulnerability scanning.

---

[Back to INDEX](INDEX.md)
