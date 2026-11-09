variable "name_prefix" {
  description = "Unique prefix for this stack's GCP resources and network tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,25}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3–27 lowercase letters, digits or hyphens, start with a letter and end with a letter or digit."
  }
}

variable "region" {
  description = "Region for the subnet and Cloud SQL instance."
  type        = string
}

variable "zone" {
  description = "VM zone within the chosen region."
  type        = string
}

variable "allowed_source_cidr" {
  description = "Public IPv4 CIDR allowed to access SSH and HTTP."
  type        = string
}
