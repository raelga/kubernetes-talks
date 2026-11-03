resource "random_id" "bucket_suffix" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 6
}

data "aws_caller_identity" "current" {}

resource "awscc_s3_bucket" "exercise" {
  bucket_name = var.bucket_name != null ? var.bucket_name : "tfexercise-${var.account_id}-${var.lab_id}-${random_id.bucket_suffix[0].hex}"

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
  tags = [
    { key = "Project", value = "TerraformS3Intro" },
    { key = "LabId", value = var.lab_id },
    { key = "ManagedBy", value = "Terraform" },
    { key = "Purpose", value = "Exercise" },
    { key = "Demonstration", value = var.demo_tag },
  ]

  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.account_id
      error_message = "The active AWS account does not match account_id."
    }
  }
}

resource "aws_s3_object" "hello" {
  bucket                 = awscc_s3_bucket.exercise.bucket_name
  key                    = "hello.txt"
  source                 = "${path.module}/../files/hello.txt"
  source_hash            = filemd5("${path.module}/../files/hello.txt")
  content_type           = "text/plain; charset=utf-8"
  server_side_encryption = "AES256"

  depends_on = [awscc_s3_bucket.exercise]
}
