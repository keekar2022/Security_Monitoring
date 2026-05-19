# AWS Terraform — Security Monitoring

EC2 ASG + ALB + S3 + Secrets Manager (OSCAL-Reports patterns).

## Prerequisites

- Terraform >= 1.0, AWS CLI, credentials (e.g. `aws sso login`)
- Image Factory EMR AMI access or set `secmon_ami_id` in tfvars
- Populate Secrets Manager after first apply

## Quick start (OSCAL env layout)

```bash
./scripts/aws_deploy.sh --verify
cp terraform/envs/aws1590/terraform.tfvars.example terraform/envs/aws1590/terraform.tfvars
# Edit tfvars (CIDRs, bucket name, image_factory_owner_id)

./scripts/aws_deploy.sh --full
./scripts/aws_deploy.sh --update           # periodic app / metrics updates
```

Manual Terraform only:

```bash
export AWS_PASS_ENTRY=AWS/AMS_1590-STG
export TERRAFORM_DIR="$PWD/terraform/envs/aws1590"
./terraform/run-with-aws-pass.sh init
./terraform/run-with-aws-pass.sh plan -out=tfplan
./terraform/run-with-aws-pass.sh apply tfplan
```

Root `terraform/*.tf` modules are symlinked from `envs/aws1590/` (AMS_1590-STG account).

## After apply

1. Update secrets (replace placeholders):
   ```bash
   aws secretsmanager put-secret-value --secret-id ams-secmon/secmon/app --secret-string file://app-secret.json
   aws secretsmanager put-secret-value --secret-id ams-secmon/secmon/trendmicro --secret-string file://trendmicro-secret.json
   ```
2. Package and upload app release:
   ```bash
   ./scripts/package_app_release.sh 2.0.0 $(terraform output -raw s3_bucket_name)
   ```
3. Upload existing metrics (optional):
   ```bash
   aws s3 sync ./data/ s3://$(terraform output -raw s3_bucket_name)/data/
   ```
4. Point DNS (CNAME) to `alb_dns_name`; set Okta redirect URI to `https://<your-domain>/`
5. Trigger instance refresh or terminate instance to re-run user_data bootstrap

See [docs/AWS_DEPLOYMENT.md](../docs/AWS_DEPLOYMENT.md) for full runbook.

## Outputs

- `alb_dns_name` — ALB hostname
- `s3_bucket_name` — app releases + metrics
- `asg_name`, `launch_template_name` — for OS refresh Lambda

## Monthly OS refresh

Lambda runs every **Thursday 06:00 UTC**; executes only on **Thursday after Patch Tuesday**.
Requires `image_factory_owner_id` in tfvars. Manual test:

```bash
aws lambda invoke --function-name ams-secmon-monthly-os-refresh \
  --payload '{"force": true}' out.json && cat out.json
```
