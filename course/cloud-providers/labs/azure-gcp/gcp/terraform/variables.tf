variable "project_id" {
  description = "Existing instructor project ID, not its number or display name."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Provide a valid GCP project ID (6–30 characters)."
  }
}
variable "region" {
  description = "Explicit instructor region, for example europe-west1."
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "Provide a valid GCP region."
  }
}
variable "zone" {
  description = "Explicit zone belonging to region, for example europe-west1-b."
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.zone))
    error_message = "Provide a valid GCP zone."
  }
}
variable "lab_id" {
  description = "Your unique identifier, matching the one used in Azure."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}[a-z0-9]$", var.lab_id))
    error_message = "lab_id: 3–12 lowercase letters/digits/hyphens, starting with a letter."
  }
}
variable "http_client_cidr" {
  description = "Explicit instructor outbound IPv4 /24–/32; prefer /32."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.http_client_cidr)) && can(regex("/(2[4-9]|3[0-2])$", var.http_client_cidr))
    error_message = "Provide a restricted IPv4 CIDR /24–/32; never 0.0.0.0/0."
  }
}
variable "machine_type" {
  description = "Small machine previously checked in the region/zone."
  type        = string
  default     = "e2-micro"
  validation {
    condition     = contains(["e2-micro", "e2-small"], var.machine_type)
    error_message = "The exercise allows e2-micro or e2-small; it does not assume free usage."
  }
}
variable "bucket_name" {
  description = "New globally available name; null adds a random suffix persisted in state."
  type        = string
  default     = null
  validation {
    condition = var.bucket_name == null ? true : (
      can(regex("^[a-z0-9][a-z0-9_-]{1,61}[a-z0-9]$", var.bucket_name)) &&
      !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$|^goog|google|g00gle", var.bucket_name))
    )
    error_message = "Use null or 3–63 lowercase letters/digits/hyphens/underscores, alphanumeric ends and no Google reserved names."
  }
}
