variable "aws_region" {
  description = "AWS deployment region."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "instance_profile_name" {
  description = "Existing instance profile; Academy supplies LabInstanceProfile."
  type        = string
  default     = "LabInstanceProfile"
}

variable "lab_id" {
  description = "Optional deployment label, 3–20 lowercase letters, digits or internal hyphens."
  type        = string
  default     = "wp-asg-lesson"
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
  default     = "6.7.1"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.wordpress_version))
    error_message = "Pin a stable three-component WordPress version."
  }
}

variable "wordpress_sha256" {
  description = "SHA-256 of the official WordPress release tarball."
  type        = string
  default     = "33529cd638c845007e8e0d26c91d60c9c16b822c849c8deead03d0c851a26deb"
  validation {
    condition     = can(regex("^[a-f0-9]{64}$", var.wordpress_sha256))
    error_message = "Use the lowercase SHA-256 digest of the selected WordPress archive."
  }
}


variable "state_bucket" {
  description = "S3 bucket containing the shared network and database states."
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
