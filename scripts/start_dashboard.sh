#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Wrapper → scripts/debug/start_dashboard.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/debug/start_dashboard.sh" "$@"
