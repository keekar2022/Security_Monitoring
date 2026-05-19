#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Wrapper → scripts/debug/repair_ec2_streamlit.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/debug/repair_ec2_streamlit.sh" "$@"
