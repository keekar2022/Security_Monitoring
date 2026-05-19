#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Wrapper → scripts/debug/diagnose_aws_deploy.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/debug/diagnose_aws_deploy.sh" "$@"
