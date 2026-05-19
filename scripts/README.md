# Scripts — Security Monitoring

Production path: **AWS EC2 + S3 + Secrets Manager** ([docs/AWS_DEPLOYMENT.md](../docs/AWS_DEPLOYMENT.md)).

## Core — AWS deploy (laptop)

| Script | Purpose |
|--------|---------|
| `aws_deploy.sh` | **`--verify`** preflight · **`--full`** fresh deploy · **`--update`** app/metrics |
| `verify_aws_deploy.sh` | Wrapper → `aws_deploy.sh --verify` |
| `aws_deploy_fresh.sh` | Wrapper → `aws_deploy.sh --full` |
| `aws_deploy_update.sh` | Wrapper → `aws_deploy.sh --update` |
| `package_app_release.sh` | Build & upload `releases/<ver>/` to S3 |
| `push_local_metrics_to_s3.sh` | Upload laptop `data/` to S3 |
| `migrate_secrets_to_aws.sh` | pass → Secrets Manager |
| `lib/deploy_common.sh` | Shared helpers (not run directly) |

Terraform: `../terraform/run-with-aws-pass.sh`, `../terraform/scripts/list-emr-candidate-amis.sh`

## Core — EC2 (on instance)

| Script | Purpose |
|--------|---------|
| `ec2_fetch_secrets.sh` | Secrets Manager → `/run/secmon/*.env` |
| `run_scheduled_collect.sh` | Collect metrics (`--ec2` on production; local uses pass/env) |
| `ec2_daily_collect.sh` | Cron wrapper → `run_scheduled_collect.sh --ec2` |
| `sync_metrics_s3.sh` | `data/` → S3 (local legacy collect path) |

Requires `/opt/secmon/deploy.env` with `METRICS_S3_BUCKET` (created by user-data).

## Core — build

| Script | Purpose |
|--------|---------|
| `write_version.py` | Called by `../bump_version.sh` |

## Debug & local tooling

See **[debug/README.md](debug/README.md)** — diagnose, repair, pass helpers, local Streamlit, legacy CSV imports.

Wrappers at `scripts/<name>` still work; implementations live under `scripts/debug/`.

## Removed (legacy)

- `publish_streamlit_github.sh`, `migrate_pass_to_cloud_credentials.sh`, `verify_cloud_setup.sh`
- `.github/workflows/collect-metrics.yml` — use EC2 cron + S3
- `terraform/scripts/deploy-fresh.sh`, `deploy-update.sh` — use `aws_deploy.sh`
