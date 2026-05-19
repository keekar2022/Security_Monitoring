# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Image Factory AMI resolution (OSCAL pattern)
# ------------------------------------------------------------------------------
# Adobe Image Factory – AMI best practices (docs/AWS_OPERATIONS.md#adobe-image-factory-ami-usage-for-terraform)
# ------------------------------------------------------------------------------
# - AMS InfraSec tickets (e.g. SSAAU-169) expect the Image Factory flavor **Amazon Linux 2023 EMR**,
#   not only generic AL2023 or the public Amazon-owned al2023-ami-* fallback.
# - Default: Adobe Image Factory Amazon Linux 2023 / EMR (add AMI IDs below or use dynamic lookup).
#   When not in map and no dynamic lookup, use native Amazon Linux 2023 (may not satisfy EMR tickets).
# - use_image_factory_ami = true (default): Image Factory AMI if resolved; else native AL2023.
# - use_image_factory_ami = false: native Amazon Linux 2023 only.
# - Optional overrides: oscal_ami_id in terraform.tfvars.
# - Discover candidates: terraform/scripts/list-emr-candidate-amis.sh (with AWS creds).
# - S3 bucket naming (AMS): lowercase, e.g. ams-oscal-<account-id> (see s3.tf).
# - References: Image Factory Wiki, UI (imagefactory.corp.adobe.com).
# ------------------------------------------------------------------------------

# First choice: Adobe Image Factory Amazon Linux 2023 (prefer **EMR** flavor per AMS security) by region.
# Set image_factory_amazon_linux_ami_us_east_1 in terraform.tfvars, or add entries below; when an entry exists for aws_region, it is used; else native Amazon Linux 2023.
locals {
  image_factory_amazon_linux_by_region = merge(
    {
      # Add more regions here if needed (same AMI for Green and Blue).
      # Example: "eu-west-1" = "ami-xxxxxxxx"
    },
    var.image_factory_amazon_linux_ami_us_east_1 != null ? { "us-east-1" = var.image_factory_amazon_linux_ami_us_east_1 } : {}
  )
  image_factory_ami_id_amazon_linux = lookup(local.image_factory_amazon_linux_by_region, var.aws_region, null)
  image_factory_ami_id_static      = local.image_factory_ami_id_amazon_linux
}

# Optional: dynamic lookup – only when explicitly enabled and a static regional AMI is not pinned.
locals {
  image_factory_dynamic_lookup = (
    var.use_image_factory_ami
    && var.image_factory_enable_dynamic_lookup
    && var.image_factory_owner_id != null
    && trimspace(var.image_factory_owner_id) != ""
    && var.image_factory_ami_name_pattern != null
    && local.image_factory_ami_id_static == null
  )
}

# Dynamic lookup (fails at plan if no AMIs match — keep image_factory_enable_dynamic_lookup false unless shared AMIs exist).
data "aws_ami" "image_factory" {
  count = local.image_factory_dynamic_lookup ? 1 : 0

  most_recent = true
  owners      = [var.image_factory_owner_id]

  filter {
    name   = "name"
    values = [var.image_factory_ami_name_pattern]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = [var.instance_architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  # Static regional AMI → dynamic lookup (when enabled) → null (locals.tf uses native AL2023).
  image_factory_ami_id = var.use_image_factory_ami ? coalesce(
    local.image_factory_ami_id_static,
    try(data.aws_ami.image_factory[0].id, null),
  ) : null
}

# Fallback only when Image Factory is not used or not available: native Amazon Linux 2023 (maintained by Amazon).
data "aws_ami" "amazon_linux" {
  most_recent  = true
  owners       = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = [var.instance_architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  # Fallback AMI when Image Factory is not available: native Amazon Linux 2023.
  default_fallback_ami_id = data.aws_ami.amazon_linux.id
}
