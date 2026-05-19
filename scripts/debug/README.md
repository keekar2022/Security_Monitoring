# Debug & local tooling

Scripts here are **not** part of the EC2 runtime path (cron, user-data, S3 release). Use from your laptop for troubleshooting, local dev, pass maintenance, or legacy data import.

| Script | Purpose |
|--------|---------|
| `diagnose_aws_deploy.sh` | ALB / target group / ASG health checks |
| `repair_ec2_streamlit.sh` | SSM repair Streamlit on EC2 (502 / unhealthy) |
| `verify_pass_tokens.sh` | Validate pass token format (single-line) |
| `update_pass_credential.sh` | Interactive pass entry update |
| `start_dashboard.sh` | Run Streamlit locally |
| `import_aem_govau_scan_reports.py` | Bulk AEM CSV → `data/server_vulnerabilities_legacy/` |
| `import_splunk_scan_reports.py` | Splunk Nexpose weekly import |

Shell scripts (`diagnose_*`, `repair_*`, etc.) have thin wrappers at `scripts/<name>`. Python import CLIs live **only** here (no duplicate under `scripts/`).

Production scripts: [../README.md](../README.md) · [AWS deployment](../../docs/AWS_DEPLOYMENT.md)
