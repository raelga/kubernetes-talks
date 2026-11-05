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
  default     = "wordpress"
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.lab_id))
    error_message = "Use 3–20 lowercase letters, digits or hyphens, starting with a letter and ending with a letter or digit."
  }
}



variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "repository_ref" {
  description = "Published public Git ref; use a commit SHA for repeatability. Changing it replaces EC2."
  type        = string
  default     = "main"
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$", var.repository_ref))
    error_message = "Use a Git SHA, branch or tag without shell metacharacters."
  }
}

variable "wordpress_version" {
  description = "Exact stable WordPress version downloaded and checksum-verified by WP-CLI."
  type        = string
  default     = "7.1.4"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.wordpress_version))
    error_message = "Pin a stable three-component WordPress version."
  }
}

variable "enable_database" {
  description = "Persist false for the web stage, then change to true for the database stage."
  type        = bool
  default     = false
}

variable "database_instance_class" {
  description = "Select an orderable small MySQL class in this region/account."
  type        = string
  default     = "db.t4g.micro"
}

variable "mysql_engine_version" {
  description = "MySQL release or version prefix resolved through the regional RDS engine catalog."
  type        = string
  default     = "8.4.11"
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
