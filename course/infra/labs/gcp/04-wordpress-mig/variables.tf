variable "name_prefix" {
  description = "Unique prefix for this deployment's GCP resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,25}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3–27 lowercase letters, digits or hyphens, start with a letter and end with a letter or digit."
  }
}

variable "project_id" {
  description = "Approved Google Cloud project ID; null uses the provider's environment configuration."
  type        = string
  default     = null
}

variable "region" {
  description = "Region for the subnet and Cloud SQL instance."
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "VM zone within the chosen region."
  type        = string
  default     = "us-west1-b"
}

variable "allowed_source_cidr" {
  description = "Your current public IPv4 CIDR for SSH and HTTP; use /32 wherever possible."
  type        = string

  validation {
    condition = (
      can(cidrhost(var.allowed_source_cidr, 0)) &&
      can(regex("^[0-9.]+/(8|9|[12][0-9]|3[0-2])$", var.allowed_source_cidr))
    )
    error_message = "Use an IPv4 CIDR with a prefix between /8 and /32; prefer your public IP as /32."
  }
}
