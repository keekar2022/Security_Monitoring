#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Wrapper → scripts/debug/update_pass_credential.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/debug/update_pass_credential.sh" "$@"
