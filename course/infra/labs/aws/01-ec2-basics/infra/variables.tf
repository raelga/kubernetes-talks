variable "lab_id" {
  description = "Unique deployment label, 3–20 lowercase letters, digits or internal hyphens."
  type        = string
  default     = "ec2-basics"
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.lab_id))
    error_message = "lab_id must be 3–20 characters, start with a letter and end with a letter or digit."
  }
}


variable "instance_type" {
  description = "An available x86_64 EC2 instance type compatible with Amazon Linux 2023."
  type        = string
  default     = "t3.micro"
  nullable    = false
}

variable "repository_ref" {
  description = "Public repository commit SHA, branch or tag. Pin a full commit SHA for reproducible application checkout."
  type        = string
  default     = "main"
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._/-]{0,199}$", var.repository_ref)) && !strcontains(var.repository_ref, "..")
    error_message = "Use a commit SHA or a plain branch/tag ref without whitespace, shell characters or '..'."
  }
}

variable "domain_name" {
  description = "Optional new public application hostname in hosted_zone_id. Set both DNS inputs or neither."
  type        = string
  default     = null
  validation {
    condition     = (var.domain_name == null) == (var.hosted_zone_id == null)
    error_message = "domain_name and hosted_zone_id must both be set or both be null."
  }
  validation {
    condition     = var.domain_name == null ? true : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "Use a lowercase public hostname without a wildcard or trailing dot."
  }
}

variable "hosted_zone_id" {
  description = "Existing public Route 53 hosted zone ID. The zone is never created or deleted."
  type        = string
  default     = null
  validation {
    condition     = var.hosted_zone_id == null ? true : can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "Specify a Route 53 hosted zone ID beginning with Z."
  }
}
