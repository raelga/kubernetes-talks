resource "random_id" "bucket_suffix" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 6
}

resource "aws_s3_bucket" "state" {
  bucket        = var.bucket_name != null ? var.bucket_name : "tfstate-${var.account_id}-${var.lab_id}-${random_id.bucket_suffix[0].hex}"
  force_destroy = false

  tags = {
    Project       = "TerraformS3Intro"
    LabId         = var.lab_id
    ManagedBy     = "Terraform"
    Purpose       = "StateBackend"
    Demonstration = var.demo_tag
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
