variable "instance_profile_name" {
  description = "Existing instance profile; Academy supplies LabInstanceProfile."
  type        = string
  default     = "LabInstanceProfile"
}

variable "allow_dashboard_updates" {
  description = "Allow WordPress core updates on the instance for the version-drift experiment."
  type        = bool
  default     = false
}

variable "lab_id" {
  description = "Optional deployment label, 3–20 lowercase letters, digits or internal hyphens."
  type        = string
  default     = "wp-module"
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.lab_id))
    error_message = "Use 3–20 lowercase letters, digits or hyphens, starting with a letter and ending with a letter or digit."
  }
}



variable "instance_type" {
  type    = string
  default = "t4g.small"
}


variable "wordpress_version" {
  description = "Exact stable WordPress release; override wordpress_sha256 together with this value."
  type        = string
  default     = "7.1.4"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.wordpress_version))
    error_message = "Pin a stable three-component WordPress version."
  }
}

variable "wordpress_sha256" {
  description = "SHA-256 of the official WordPress release tarball."
  type        = string
  default     = "881e53a4681ff2cd911651b11cccdede5ae477ddf0765af5d6a1a8b219a1d835"
  validation {
    condition     = can(regex("^[a-f0-9]{64}$", var.wordpress_sha256))
    error_message = "Use the lowercase SHA-256 digest of the selected WordPress archive."
  }
}


variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_security_group_id" {
  type = string
}

variable "database_endpoint" {
  description = "Hostname of the shared MySQL RDS instance."
  type        = string
}

variable "master_secret_arn" {
  description = "ARN of the RDS-managed administrator secret."
  type        = string
}

variable "domain_name" {
  description = "Optional NEW hostname in your public Route 53 zone; requires hosted_zone_id."
  type        = string
  default     = null
  validation {
    condition     = var.domain_name == null ? true : can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", var.domain_name))
    error_message = "Use a lowercase DNS hostname without wildcard or trailing dot."
  }
}

variable "hosted_zone_id" {
  description = "Existing public Route 53 zone; never created or deleted by this lab."
  type        = string
  default     = null
}

variable "ami_id" {
  type    = string
  default = null
}

variable "s3_bucket" {
  type    = string
  default = ""
}
