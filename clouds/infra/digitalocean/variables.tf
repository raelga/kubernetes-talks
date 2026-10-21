variable "region" {
  description = "DigitalOcean region for DOKS."
  type        = string
  default     = "syd1"
}

variable "cluster_name" {
  description = "DOKS cluster name."
  type        = string
  default     = "clouds-doks"
}

variable "kubernetes_version" {
  description = "DOKS Kubernetes version slug."
  type        = string
  default     = "1.36.5-do.1"
}

variable "control_plane_ha" {
  description = "Opt in only after approving the separately billed HA control plane. DigitalOcean does not allow disabling HA on an existing cluster; retain true until separately approved recreation."
  type        = bool
  default     = false
}
variable "control_plane_allowed_cidrs" {
  description = "IPv4/IPv6 CIDRs allowed to reach the DOKS API. This public demo allows all IPv4; Kubernetes authentication is still required."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
