variable "project_id" {
  description = "GCP project that owns the lab cluster."
  type        = string
  default     = "bcncloud-gke"
}

variable "region" {
  description = "GCP region for GKE."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "Zonal location for the low-cost lab cluster."
  type        = string
  default     = "asia-northeast1-a"
}

variable "kubernetes_version" {
  description = "GKE control-plane and node version in the selected zone."
  type        = string
  default     = "1.36.4-gke.2326000"
}

variable "cluster_api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API. This demo allows any IPv4; Kubernetes authentication is still required."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.cluster_api_allowed_cidrs) > 0 && alltrue([for cidr in var.cluster_api_allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Provide at least one valid CIDR."
  }
}
