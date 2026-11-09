resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "state" {
  name                        = "upc-k8s-terraform-state-${random_id.bucket_suffix.hex}"
  location                    = var.location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }
}
