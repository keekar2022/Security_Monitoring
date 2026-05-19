#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# List Amazon Linux 2023 EMR AMIs (Image Factory naming). OSCAL pattern.
set -euo pipefail

REGION="${1:-us-east-1}"
ARCH="${2:-x86_64}"

command -v aws >/dev/null || { echo "aws CLI required" >&2; exit 1; }

echo "Region: ${REGION}  Architecture: ${ARCH}" >&2
aws ec2 describe-images \
  --region "${REGION}" \
  --executable-users self \
  --filters \
  "Name=architecture,Values=${ARCH}" \
  "Name=name,Values=*Amazon*Linux*2023*EMR*,*amazon*linux*2023*emr*" \
  "Name=state,Values=available" \
  --query 'sort_by(Images,&CreationDate)[-25:].[ImageId,Name,CreationDate]' \
  --output table
