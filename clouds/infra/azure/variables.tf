variable "subscription_id" {
  description = "Azure subscription ID. Defaults to the currently selected lab subscription."
  type        = string
  default     = "c825038c-1551-4ccf-8ddd-24b49f8e14b4"
}

variable "location" {
  description = "Azure region for AKS."
  type        = string
  default     = "westeurope"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "clouds-aks"
}

variable "kubernetes_version" {
  description = "Kubernetes version; keep aligned with the other lab providers."
  type        = string

  default = "1.36.4"
}
variable "cluster_api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public AKS API. This demo allows any IPv4; Kubernetes authentication is still required."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.cluster_api_allowed_cidrs) > 0 && alltrue([for cidr in var.cluster_api_allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Provide at least one valid CIDR."
  }
}
