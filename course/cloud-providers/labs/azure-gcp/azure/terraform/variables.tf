variable "subscription_id" {
  description = "Explicit instructor subscription; no default subscription is selected."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "Provide the instructor subscription UUID."
  }
}
variable "location" {
  description = "Previously authorized region with quota, for example westeurope."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "Use the Azure region name without spaces."
  }
}
variable "lab_id" {
  description = "Your unique instructor/group identifier, 3–12 characters."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}[a-z0-9]$", var.lab_id))
    error_message = "lab_id: 3–12 lowercase ASCII letters/digits/hyphens, starting with a letter."
  }
}
variable "http_client_cidr" {
  description = "Explicit instructor outbound IPv4 /24–/32; prefer a single /32."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.http_client_cidr)) && can(regex("/(2[4-9]|3[0-2])$", var.http_client_cidr))
    error_message = "Provide a restricted IPv4 CIDR /24–/32; never 0.0.0.0/0."
  }
}
variable "ssh_public_key_path" {
  description = "Local path to an existing PUBLIC SSH key. Does not open port 22."
  type        = string
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) ", trimspace(file(pathexpand(var.ssh_public_key_path)))))
    error_message = "The path must contain an existing PUBLIC RSA/ed25519 SSH key, never the private key."
  }
}
variable "vm_size" {
  description = "Small SKU with quota previously checked by the instructor."
  type        = string
  default     = "Standard_B1s"
  validation {
    condition     = contains(["Standard_B1s", "Standard_B1ms", "Standard_B2s"], var.vm_size)
    error_message = "The exercise allows only Standard_B1s, B1ms or B2s; check availability and price."
  }
}
variable "storage_account_name" {
  description = "New globally available name; null adds a random suffix persisted in state."
  type        = string
  default     = null
  validation {
    condition     = var.storage_account_name == null ? true : can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Use null or 3–24 lowercase letters and digits."
  }
}
