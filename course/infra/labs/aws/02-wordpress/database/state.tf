variable "state_bucket" {
  description = "S3 bucket shared by the infrastructure and database Terraform states."
  type        = string
}

variable "mysql_password" {
  description = "The dedicated application password loaded from Secrets Manager by with-ssm-tunnel.sh."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "mysql_password_version" {
  description = "Non-secret revision used to signal application password rotation to the MySQL provider."
  type        = number

  validation {
    condition     = var.mysql_password_version >= 1 && var.mysql_password_version == floor(var.mysql_password_version)
    error_message = "mysql_password_version must be a positive integer."
  }
}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket       = var.state_bucket
    key          = "wordpress/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
