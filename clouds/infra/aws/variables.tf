variable "region" {
  description = "AWS region for the EKS cluster."
  type        = string
  default     = "ap-southeast-2"
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
