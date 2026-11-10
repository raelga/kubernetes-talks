resource "random_id" "media_suffix" {
  byte_length = 4
}

# Cloud Control avoids the S3 object-lock read denied in some Academy labs.
resource "awscc_s3_bucket" "media" {
  bucket_name = "${var.lab_id}-media-${random_id.media_suffix.hex}"
  bucket_encryption = {
    server_side_encryption_configuration = [{
      server_side_encryption_by_default = { sse_algorithm = "AES256" }
    }]
  }
  public_access_block_configuration = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
  ownership_controls = {
    rules = [{ object_ownership = "ObjectWriter" }]
  }
}

output "media_bucket" {
  value = awscc_s3_bucket.media.bucket_name
}
