variable "project_id" {
  description = "Approved Google Cloud project ID."
  type        = string
  default     = null
}

variable "region" {
  description = "Region for the lab subnet; must contain the selected zone."
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "Zone for the VM, within the selected region."
  type        = string
  default     = "us-west1-b"
}

variable "allowed_source_cidr" {
  description = "Your current public IPv4 address in CIDR notation (prefer /32); allowed to reach SSH and HTTP."
  type        = string

  validation {
    condition = (
      can(cidrhost(var.allowed_source_cidr, 0)) &&
      can(regex("^[0-9.]+/(8|9|[12][0-9]|3[0-2])$", var.allowed_source_cidr))
    )
    error_message = "Use an IPv4 CIDR with a prefix between /8 and /32; prefer your public IP as /32."
  }
}
