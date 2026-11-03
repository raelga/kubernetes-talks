resource "random_id" "bucket_suffix" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 6
}

data "aws_caller_identity" "current" {}

resource "awscc_s3_bucket" "state" {
  bucket_name = var.bucket_name != null ? var.bucket_name : "tfstate-${var.account_id}-${var.lab_id}-${random_id.bucket_suffix[0].hex}"

  public_access_block_configuration = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
  ownership_controls = {
    rules = [{ object_ownership = "BucketOwnerEnforced" }]
  }
  bucket_encryption = {
    server_side_encryption_configuration = [{
      server_side_encryption_by_default = { sse_algorithm = "AES256" }
    }]
  }
  versioning_configuration = {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
  tags = [
    { key = "Project", value = "TerraformS3Intro" },
    { key = "LabId", value = var.lab_id },
    { key = "ManagedBy", value = "Terraform" },
    { key = "Purpose", value = "StateBackend" },
    { key = "Stage", value = var.stage },
  ]

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.account_id
      error_message = "La cuenta AWS activa no coincide con account_id."
    }
  }
}
