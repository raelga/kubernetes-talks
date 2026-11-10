variable "subscription_id" {
  description = "Subscription authorized for this lab; supply via TF_VAR_subscription_id."
  type        = string
}

variable "location" {
  description = "Azure region where the selected VM and MySQL SKUs are available."
  type        = string
  default     = "westeurope"
}

variable "ssh_public_key" {
  description = "SSH public key for the VM (never the private key)."
  type        = string
}

variable "admin_cidr" {
  description = "Your public IPv4 address in CIDR notation for SSH access."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Provide a valid, restricted IPv4 CIDR, not 0.0.0.0/0."
  }
}

variable "vm_size" {
  type    = string
  default = "Standard_D2as_v7"
}

variable "zone" {
  type    = string
  default = "3"
}
