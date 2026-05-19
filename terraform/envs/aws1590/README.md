# AMS_1590-STG — Security Monitoring Terraform

Working directory for the **AMS_1590-STG** AWS account.

Credentials: `pass show AWS/AMS_1590-STG`

## Apply (from repo root)

```bash
export AWS_PASS_ENTRY=AWS/AMS_1590-STG
export TERRAFORM_DIR="$PWD/terraform/envs/aws1590"

./terraform/run-with-aws-pass.sh init
./terraform/run-with-aws-pass.sh plan -out=tfplan
./terraform/run-with-aws-pass.sh apply tfplan
```

Copy `terraform.tfvars.example` to `terraform.tfvars` and customize before apply.

## Image Factory AMI

```bash
./terraform/scripts/list-emr-candidate-amis.sh us-east-1 x86_64
```

Set `image_factory_amazon_linux_ami_us_east_1` or `image_factory_owner_id` in tfvars.

**Golden AMI (optional):** bake Python venv before snapshot:

```bash
sudo /opt/secmon/app/scripts/image_factory/bake_secmon_ami.sh
```

**TLS:** `create_alb_certificate = false`; use `scripts/tls/renew_le_import_acm.sh` and `alb_ssl_certificate_arn`.

See [../../../docs/AWS_DEPLOYMENT.md](../../../docs/AWS_DEPLOYMENT.md) for post-apply steps.
