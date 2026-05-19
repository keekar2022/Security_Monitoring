# AWS deployment (EC2 ASG + ALB + S3 + Secrets Manager)

Self-hosted Security Monitoring dashboard on AWS. **No Streamlit Cloud** or **scheduled GitHub Actions** in production.

**Target account:** `AMS_1590-STG` — AWS credentials in Pass: `pass show AWS/AMS_1590-STG`

## Architecture

- **Terraform** (`terraform/`, apply from `terraform/envs/aws1590/`) — dedicated VPC, ALB → Streamlit :8501, ASG (default **2** instances across 2 AZs)
- **S3** — `releases/<version>/` (app), `data/` (metrics JSONL)
- **Secrets Manager** — `{project_name}/secmon/app`, `{project_name}/secmon/trendmicro`
- **Cron** — daily collection 06:00 UTC on EC2 (`go/bin/collector --run-all --publish-s3`)
- **Lambda** — monthly OS refresh (Thursday after Microsoft Patch Tuesday)
- **SSM** — Session Manager access; optional 30-minute post-boot association

Rollback application baseline: git tag **`v2.0.0`**.

## OS vs application patching

| Layer | Owner | How |
|-------|--------|-----|
| OS / AMI | Automated | Monthly ASG instance refresh + latest Image Factory EMR AMI |
| Python / Go / app | You | `./scripts/package_app_release.sh <ver> <bucket>` then instance refresh |
| API secrets | You | Secrets Manager; picked up on next boot or `ec2_fetch_secrets.sh` |

## Deploy scripts (recommended)

| Command | Purpose |
|---------|---------|
| `./scripts/aws_deploy.sh --verify` | Preflight (tools, tfvars, local `data/`, optional AWS) |
| `./scripts/aws_deploy.sh --full` | Terraform + app release + **local metrics → S3** + instance refresh |
| `./scripts/aws_deploy.sh --update` | App update via **SSM repair** (default; no instance refresh) |
| `./scripts/aws_deploy.sh --update --with-refresh` | App update + ASG instance refresh (OS AMI changes only) |
| `./scripts/aws_deploy.sh --update --metrics-only` | Metrics → S3 → **SSM sync** to EC2 |
| `./scripts/debug/fix_aws_dashboard.sh` | **Recommended:** metrics + app release + SSM repair (stable) |
| `./scripts/debug/sync_ec2_metrics_from_s3.sh` | Pull `s3://…/data/` onto running instances only |
| `./scripts/push_local_metrics_to_s3.sh` | Laptop `data/` → `s3://<bucket>/data/` only |
| `./scripts/migrate_secrets_to_aws.sh` | pass → Secrets Manager |

Legacy wrappers (`verify_aws_deploy.sh`, `aws_deploy_fresh.sh`, `aws_deploy_update.sh`) call the same script.

**Carry dashboard data from laptop to EC2:** metrics live under `data/` locally. Upload with `./scripts/push_local_metrics_to_s3.sh`, then **`./scripts/debug/sync_ec2_metrics_from_s3.sh`** (avoid instance refresh for metrics-only — it causes 502s during bootstrap). EC2 bootstrap syncs `s3://<bucket>/data/` → `/opt/secmon/data/`.

**Avoid 502 during deploy:** Prefer `./scripts/debug/fix_aws_dashboard.sh` or `./scripts/aws_deploy.sh --update` (SSM in-place). Use `--with-refresh` only when changing the launch template / OS AMI.

```bash
./scripts/aws_deploy.sh --verify
cp terraform/envs/aws1590/terraform.tfvars.example terraform/envs/aws1590/terraform.tfvars
# edit tfvars
./scripts/aws_deploy.sh --full          # interactive Terraform confirm
./scripts/aws_deploy.sh --full --auto-approve
./scripts/aws_deploy.sh --update      # app release + instance refresh
./scripts/aws_deploy.sh --update --metrics-only
```

## Deploy steps (manual)

### 1. Terraform

```bash
export AWS_PASS_ENTRY=AWS/AMS_1590-STG
export TERRAFORM_DIR="$PWD/terraform/envs/aws1590"

cp terraform/envs/aws1590/terraform.tfvars.example terraform/envs/aws1590/terraform.tfvars
# Edit: s3_bucket_name, default_allowed_cidr_blocks, image_factory_owner_id

./terraform/run-with-aws-pass.sh init
./terraform/run-with-aws-pass.sh plan -out=tfplan
./terraform/run-with-aws-pass.sh apply tfplan
```

Outputs: `alb_dns_name`, `s3_bucket_name`, `asg_name`, `secret_app_arn`.

### 2. Secrets Manager

**Migrate from laptop (pass + `.streamlit/secrets.toml`):**

```bash
# Set production URL if ALB/DNS is ready (must match Okta redirect URI)
export STREAMLIT_APP_URL=https://<your-alb-or-domain>/

./scripts/migrate_secrets_to_aws.sh
./scripts/migrate_secrets_to_aws.sh --refresh-ec2   # push + reload on running EC2 via SSM
```

This uploads the same keys EC2 reads via `ec2_fetch_secrets.sh`. Trend Micro tokens come from `pass` (`TrendMicro/<env>/api_token`); Okta/admin settings from `.streamlit/secrets.toml`.

Populate manually (replace Terraform placeholders):

**`ams-secmon/secmon/app`**

| Key | Example |
|-----|---------|
| `OKTA_DOMAIN` | `aemgovau.oktapreview.com` (host only) |
| `OKTA_CLIENT_ID` | from Okta app |
| `OKTA_CLIENT_SECRET` | from Okta app |
| `STREAMLIT_APP_URL` | `https://secmon.yourdomain.com/` |
| `SETTINGS_ADMIN_USER` | bootstrap admin |
| `SETTINGS_ADMIN_PASSWORD` | change after first login |
| `COLLECTION_FREQUENCY` | `daily` |

**`ams-secmon/secmon/trendmicro`** — four `TRENDMICRO_*_API_TOKEN` keys per environment.

```bash
aws secretsmanager put-secret-value \
  --secret-id ams-secmon/secmon/app \
  --secret-string file://app-secret.json
```

### 3. Okta (ALB hostname)

1. Create/sign-in app **Web** with Authorization Code.
2. **Sign-in redirect URIs** (must match `STREAMLIT_APP_URL` exactly):
   - `https://<your-alb-domain>/`
   - `https://<your-alb-domain>/oauth2callback` (if used by app)
3. **Sign-out redirect URIs**: same base URL.
4. Assign users/groups.
5. Update `STREAMLIT_APP_URL` in Secrets Manager after ACM/DNS is live.

### HTTPS — Let's Encrypt + ACM import (OSCAL-Reports pattern, AMS policy)

**Policy:** ACM must not **issue** certificates; ACM may **store** imported certs. ALB terminates TLS using an imported ACM ARN.

**You cannot use `*.elb.amazonaws.com` with Let's Encrypt** — you need a hostname you control (e.g. `secmon.company.com`) and a **DNS ticket** to your DNS team.

#### DNS team checklist (manual DNS)

| Step | Record | Purpose |
|------|--------|---------|
| 1 | **TXT** `_acme-challenge.secmon.company.com` | Let's Encrypt validation (certbot prints exact name/value) |
| 2 | **CNAME** `secmon.company.com` → `terraform output alb_dns_name` | Users reach the dashboard |

#### Obtain certificate (laptop or jump host)

```bash
# Install certbot once (macOS: brew install certbot)
certbot certonly --manual --preferred-challenges dns -d secmon.company.com
# Add TXT record(s) when prompted; wait for propagation between prompts
```

#### Import into ACM and enable HTTPS on ALB

```bash
export SECMON_TLS_DOMAIN=secmon.company.com
export AWS_PASS_ENTRY=AWS/AMS_1590-STG
./scripts/tls/renew_le_import_acm.sh
```

Copy the printed **ACM certificate ARN** into `terraform/envs/aws1590/terraform.tfvars`:

```hcl
create_alb_certificate  = false
alb_ssl_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/UUID"
```

```bash
./terraform/run-with-aws-pass.sh apply
export STREAMLIT_APP_URL=https://secmon.company.com/
./scripts/migrate_secrets_to_aws.sh --refresh-ec2
```

Okta redirect URI: `https://secmon.company.com/` (trailing slash, **https**).

**Renewal (~60 days):** `certbot renew` (or repeat `certbot certonly …`), then:

```bash
export ACM_CERTIFICATE_ARN=<same-arn>
./scripts/tls/renew_le_import_acm.sh -d secmon.company.com
```

#### Verify

- `https://secmon.company.com/` — valid padlock, dashboard loads
- `http://secmon.company.com/` — redirects to HTTPS
- `default_allowed_cidr_blocks` includes your VPN/office IPs on **443**

#### Optional — ACM-issued cert (only if policy allows)

If your account may use `create_alb_certificate = true`, see Path A/B in git history or `terraform/acm.tf`. AMS_1590-STG typically uses **import only** above.

### 4. App release to S3

```bash
./scripts/package_app_release.sh 2.0.0 $(terraform -chdir=terraform/envs/aws1590 output -raw s3_bucket_name)
```

### 5. Metrics seed (optional — laptop → EC2 via S3)

```bash
./scripts/push_local_metrics_to_s3.sh
# or: aws s3 sync ./data/ s3://<bucket>/data/
```

### 6. Bootstrap instances

New instances run user_data: S3 sync app + data, Secrets → `/run/secmon/*.env`, systemd, cron.

Trigger replacement:

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name $(terraform -chdir=terraform/envs/aws1590 output -raw asg_name) \
  --preferences MinHealthyPercentage=100,InstanceWarmup=600
```

### 7. Verify

- **Use HTTP until ACM is enabled:** `http://<alb_dns_name>/` (not `https://`). Without a certificate, the ALB listens on port **80** only.
- If the browser times out: run `./scripts/debug/diagnose_aws_deploy.sh` — common causes are (1) ALB security group missing port 80, (2) your IP not in `default_allowed_cidr_blocks`, (3) unhealthy targets.
- **Refresh stuck at `complete=100%`:** Rollout finished launching instances; ASG is still in **InstanceWarmup** (default **600s**) until new targets pass `/_stcore/health`. Expect **7–12 minutes** total after `aws_deploy.sh --update`, not instant.
- **502 during refresh:** Normal while the new instance bootstraps (S3 sync, `pip install`, Streamlit start). Default ASG is **`desired=2`** so one healthy instance can serve traffic while another boots. If 502 persists **>15 min after refresh completes**, Streamlit failed bootstrap — see below.
- **502 Bad Gateway:** ALB is reachable but EC2 targets are unhealthy (Streamlit not on :8501). Fix:
  ```bash
  ./scripts/package_app_release.sh 2.0.0 ams-secmon-928475551084
  ./scripts/debug/repair_ec2_streamlit.sh
  ./scripts/debug/diagnose_aws_deploy.sh
  ```
  Then instance refresh if needed: `./scripts/aws_deploy.sh --update --metrics-only`
- ALB target healthy (`/_stcore/health`)
- `aws ssm start-session --target <instance-id>`
- `sudo /opt/secmon/app/scripts/ec2_daily_collect.sh`
- Dashboard over HTTPS; Okta login works

## Instance refresh runbook

| Scenario | Action |
|----------|--------|
| **Monthly OS patch** | Automatic: Lambda on Thursday after Patch Tuesday (requires `image_factory_owner_id` in tfvars) |
| **Manual OS refresh** | `aws lambda invoke --function-name ams-secmon-monthly-os-refresh --payload '{"force":true}' out.json` |
| **App-only deploy** | `package_app_release.sh` → `start-instance-refresh` (no Lambda AMI step) |
| **Rollback app** | `package_app_release.sh 2.0.0 <bucket>` → instance refresh |
| **Skip one month OS** | `os_refresh_enabled = false` in tfvars or disable EventBridge rule |

Before refresh, ensure last cron run completed or run `ec2_daily_collect.sh` manually (flushes metrics to S3).

## High availability (default Terraform)

| Setting | Default | Purpose |
|---------|---------|---------|
| `asg_desired_capacity` / `asg_min_size` | **2** | One unhealthy instance does not take down the dashboard |
| `capacity_rebalance` | on | ASG spreads replacements across AZs |
| ALB cross-zone | automatic | Application Load Balancers distribute across AZs by default |
| `enable_cloudwatch_alarms` | **true** | SNS topic + alarms for unhealthy targets and target 5xx |

Subscribe to the alarm topic:

```bash
terraform -chdir=terraform/envs/aws1590 output cloudwatch_alarm_sns_topic_arn
aws sns subscribe --topic-arn <arn> --protocol email --notification-endpoint you@example.com
```

## Golden AMI (faster boot, fewer false unhealthy)

Heavy `pip install` on every instance refresh causes long ALB health-check failures. Bake the venv into a custom AMI once:

1. Launch a throwaway EC2 from your Image Factory AMI; sync app to `/opt/secmon/app` (or clone repo).
2. On the instance: `sudo ./scripts/image_factory/bake_secmon_ami.sh`
3. Create AMI from the instance; set `image_factory_amazon_linux_ami_us_east_1` (or `secmon_ami_id`) in tfvars.
4. Instance refresh — user-data skips pip when `/opt/secmon/venv/.secmon-baked` exists.

Boot time drops to roughly **1–2 minutes** instead of 7–12.

## Manual operations

**Force collection** (requires `/opt/secmon/deploy.env` with `METRICS_S3_BUCKET` — created by user-data; if missing, see below):

```bash
sudo /opt/secmon/app/scripts/ec2_daily_collect.sh
# Uses go/bin/collector --run-all --publish-s3 when present
```

If `METRICS_S3_BUCKET: Set METRICS_S3_BUCKET` on an existing instance:

```bash
sudo tee /opt/secmon/deploy.env <<'EOF'
METRICS_S3_BUCKET=ams-secmon-928475551084
DATA_DIR=/opt/secmon/data
AWS_DEFAULT_REGION=us-east-1
SECMON_COLLECTION_MODE=ec2
USE_PASS=false
COLLECTOR_NON_FATAL=true
EOF
sudo /opt/secmon/app/scripts/ec2_fetch_secrets.sh
sudo /opt/secmon/app/scripts/ec2_daily_collect.sh
```

Then publish updated scripts: `./scripts/package_app_release.sh 2.0.0 ams-secmon-928475551084`

**Local test with collector:**

```bash
export METRICS_S3_BUCKET=your-bucket
./scripts/run_scheduled_collect.sh --ec2
# local laptop: USE_PASS=true ./scripts/run_scheduled_collect.sh
```

## Fix 502 / missing tabs / non-executable scripts

```bash
./scripts/debug/fix_aws_dashboard.sh
```

Uploads local `data/` (all JSONL + legacy), republishes the app release with `chmod +x` on scripts, repairs EC2 via SSM (sync S3, secrets, Streamlit).

**Tabs and data sources**

| UI section | Files under `DATA_DIR` (`/opt/secmon/data/`) |
|------------|-----------------------------------------------|
| Server Vulnerabilities-Legacy | `server_vulnerabilities_legacy/` |
| Container / Endpoint * | `container_vulnerability_metrics.jsonl`, `endpoint_*.jsonl` |

Legacy can work while Trend Micro JSONL is missing on the instance — run `push_local_metrics_to_s3.sh` then `sync_ec2_metrics_from_s3.sh` or `fix_aws_dashboard.sh`.

## Rollback (preserve S3)

Terraform is not CloudFormation: there is no automatic stack rollback. To tear down **EC2 + ALB** but **keep the S3 bucket and all objects** (`releases/`, `data/`):

```bash
./terraform/scripts/rollback-compute-preserve-s3.sh
```

The bucket has `lifecycle { prevent_destroy = true }`. Full `terraform destroy` will fail on S3 unless you remove that guard.

Re-deploy: `./terraform/run-with-aws-pass.sh apply` then `./scripts/debug/fix_aws_dashboard.sh`.

## Logs

- `/var/log/secmon-user-data.log` — bootstrap
- `/var/log/secmon/streamlit.log` — Streamlit
- `/var/log/secmon/collect.log` — cron collection

## Collection

Trend Micro metrics are collected on **EC2** (`run_scheduled_collect.sh --ec2` / cron `ec2_daily_collect.sh` → `go/bin/collector --publish-s3`). Use S3 as the source of truth.

---

## Streamlit Community Cloud (legacy)

Optional [share.streamlit.io](https://share.streamlit.io/) hosting — **display only**. Collectors run on **EC2**, not Cloud.

1. Push repo to GitHub; create app with main file `app.py`.
2. Paste secrets from [`.streamlit/secrets.toml.example`](../.streamlit/secrets.toml.example) (Okta, admin).
3. Register Okta callback: `https://YOUR-APP.streamlit.app/` (trailing slash).

Trend Micro data: EC2 collect + S3, or commit `data/*.jsonl`. Legacy AEM data: UI upload or `scripts/debug/import_*.py`, then commit `data/server_vulnerabilities_legacy/`.

**Removed:** `publish_streamlit_github.sh`, GHA `collect-metrics.yml`, `verify_cloud_setup.sh` — use `git push` and EC2 cron.

---

## AWS IAM QCR metric (AM-01-01)

Quarterly attestation helper plan: SHA256 hash of sorted IAM user names stored in **SSM Parameter Store** at `/qcr/AM-01-01/{account-id}/metric`.

**Workflow:** Run script per account → compare hash to stored value → `DEVIATION` triggers full credential report review; always write new metric for next quarter.

**IAM needs:** `ssm:GetParameter`, `ssm:PutParameter`, `iam:ListUsers` (and `GenerateCredentialReport` / `GetCredentialReport` on deviation).

**Script (planned):** `scripts/qcr-iam-metric.sh` or `scripts/qcr_iam_metric.py` — single execution per account; scheduling via EventBridge/cron is external.

```bash
aws iam generate-credential-report
aws iam get-credential-report --output text --query Content | base64 -d > credential-report.csv
```
