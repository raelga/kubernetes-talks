variable "region" {
  description = "Region authorized by the AWS Academy lab."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.region))
    error_message = "Specify a valid AWS region authorized by your lab."
  }
}

variable "account_id" {
  description = "Expected 12-digit account ID; the AWS provider and bucket precondition reject other accounts."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must contain exactly 12 digits."
  }
}

variable "lab_id" {
  description = "Teaching identifier of 3 to 20 characters; the random suffix provides uniqueness per run."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.lab_id))
    error_message = "Use 3–20 lowercase letters, digits or hyphens; start and end with a letter or digit."
  }
}

variable "bucket_name" {
  description = "Optional exact name; null generates a name with account, lab_id and a persistent random suffix."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.bucket_name == null ? true : (
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name)) &&
      !can(regex("\\.\\.|\\.-|-\\.", var.bucket_name)) &&
      !can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.bucket_name))
    )
    error_message = "Use null or an S3 name of 3–63 lowercase letters/digits/dots/hyphens, without consecutive dots, dots next to hyphens or IPv4 format; start and end with a letter or digit."
  }
}

variable "enable_versioning" {
  description = "false during the basics; enable before storing any remote state."
  type        = bool
  default     = false
}

variable "stage" {
  description = "Teaching tag changed when preparing the backend."
  type        = string
  default     = "basics"
}
