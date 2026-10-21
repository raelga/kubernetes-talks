variable "account_id" {
  description = "Cloudflare account ID for the existing zone, Worker, and D1 database."
  type        = string
}

variable "zone_name" {
  description = "Existing Cloudflare-managed DNS zone."
  type        = string
  default     = "rael.dev"
}

variable "app_hostname" {
  description = "Custom hostname served by the global Guestbook Worker."
  type        = string
  default     = "guestbook.rael.dev"
}

variable "origin_addresses" {
  description = "Public app Service hostnames or IPs keyed by aws, azure, gcp, and digitalocean. Empty string values disable individual origins; an empty map bootstraps Worker/D1 only."
  type        = map(string)
  default     = {}

  validation {
    condition = length(var.origin_addresses) == 0 || (
      toset(keys(var.origin_addresses)) == toset([
        "aws",
        "azure",
        "gcp",
        "digitalocean",
      ]) && alltrue([for address in values(var.origin_addresses) : address != null])
    )
    error_message = "Use an empty map for bootstrap, or all four keys (aws, azure, gcp, digitalocean) with string values. Use an empty string for a provider that is not ready."
  }
}
