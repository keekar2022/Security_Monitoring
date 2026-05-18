#!/bin/sh
# Serve data/ (including jsonl_viewer.html) on 8080; API on 8081.
set -e
DATA_DIR="${DATA_DIR:-/app/data}"
# Static file server for viewer and JSONL on 8080 (background)
/app/static-server -port 8080 -dir "$DATA_DIR" &
# API server on 8081 (foreground so container stays up)
exec /app/api-server --port 8081 --data-dir "$DATA_DIR" "$@"
