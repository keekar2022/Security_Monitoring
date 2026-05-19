# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

resource "aws_s3_bucket" "secmon" {
  bucket = local.s3_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "secmon" {
  bucket = aws_s3_bucket.secmon.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secmon" {
  bucket = aws_s3_bucket.secmon.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "secmon" {
  bucket = aws_s3_bucket.secmon.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "prefix_releases" {
  bucket  = aws_s3_bucket.secmon.id
  key     = "releases/"
  content = ""
}

resource "aws_s3_object" "prefix_data" {
  bucket  = aws_s3_bucket.secmon.id
  key     = "data/"
  content = ""
}

resource "aws_s3_bucket_lifecycle_configuration" "secmon" {
  bucket = aws_s3_bucket.secmon.id

  rule {
    id     = "expire-old-metrics-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
