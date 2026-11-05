data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "random_id" "bucket_suffix" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 2
}

resource "awscc_s3_bucket" "state" {
  bucket_name = var.bucket_name != null ? var.bucket_name : "upc-k8s-${var.lab_id}-${random_id.bucket_suffix[0].hex}"

  versioning_configuration = {
    status = "Enabled"
  }

  bucket_encryption = {
    server_side_encryption_configuration = [{
      server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }]
  }

  public_access_block_configuration = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }

  tags = [
    { key = "Project", value = "TerraformS3Intro" },
    { key = "LabId", value = var.lab_id },
    { key = "ManagedBy", value = "Terraform" },
    { key = "Purpose", value = "StateBackend" },
    { key = "Demonstration", value = var.demo_tag },
  ]

  lifecycle {
    prevent_destroy = true
  }
}
