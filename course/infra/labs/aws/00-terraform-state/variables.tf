variable "lab_id" {
  description = "Unique personal deployment identifier used in names and tags."
  type        = string
  default     = "terraform-state"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.lab_id))
    error_message = "Use 3–20 lowercase letters, digits or hyphens; start and end with a letter or digit."
  }
}

variable "bucket_name" {
  description = "Optional exact globally available bucket name; null uses account, lab ID and a persistent random suffix."
  type        = string
  default     = null

  validation {
    condition = var.bucket_name == null ? true : (
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name)) &&
      !can(regex("\\.\\.|\\.-|-\\.", var.bucket_name)) &&
      !can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.bucket_name))
    )
    error_message = "Use null or an S3 name of 3–63 lowercase letters/digits/dots/hyphens, without adjacent dots/hyphens or IPv4 format."
  }
}

variable "demo_tag" {
  description = "Simple tag to change when exploring a Terraform diff."
  type        = string
  default     = "initial"
}
