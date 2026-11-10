variable "subscription_id" {
  description = "Approved Azure subscription ID for this demonstration."
  type        = string
}

variable "location" {
  description = "Azure region for the lab resources."
  type        = string
  default     = "westeurope"
}

variable "allowed_source_cidr" {
  description = "Public IPv4 CIDR allowed to connect to SSH and HTTP; use your current IP as /32."
  type        = string

  validation {
    condition = (
      can(cidrhost(var.allowed_source_cidr, 0)) &&
      can(regex("^[0-9.]+/(8|9|[12][0-9]|3[0-2])$", var.allowed_source_cidr))
    )
    error_message = "Use an IPv4 CIDR with a prefix between /8 and /32; prefer your public IP as /32."
  }
}

variable "ssh_public_key" {
  description = "OpenSSH public key for the lab VM; never provide a private key."
  type        = string
}
