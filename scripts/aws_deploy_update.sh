#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Legacy wrapper — use: ./scripts/aws_deploy.sh --update
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aws_deploy.sh" --update "$@"
