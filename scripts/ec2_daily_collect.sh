#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# EC2 cron entrypoint (wrapper). Implementation: run_scheduled_collect.sh --ec2
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_scheduled_collect.sh" --ec2 "$@"
