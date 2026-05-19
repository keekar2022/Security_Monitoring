#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Wrapper → scripts/debug/verify_pass_tokens.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/debug/verify_pass_tokens.sh" "$@"
