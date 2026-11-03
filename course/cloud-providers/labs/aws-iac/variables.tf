variable "aws_region" {
  description = "Region allowed by the assigned Academy lab."
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Specify a valid AWS region authorized by the instructor."
  }
}

variable "lab_id" {
  description = "Your own unique identifier; do not reuse another learner's."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.lab_id))
    error_message = "Use 3–20 characters: initial letter, lowercase letters, digits or hyphens."
  }
}

variable "client_cidr" {
  description = "Client public IPv4 /32; the only authorized HTTP source."
  type        = string
  validation {
    condition = can(cidrnetmask(var.client_cidr)) && can(regex("/32$", var.client_cidr)) && !contains(
      ["0.0.0.0/32", "255.255.255.255/32"], var.client_cidr
    )
    error_message = "Enter your public IPv4 as x.x.x.x/32; broad networks and 0.0.0.0 are not allowed."
  }
}

variable "instance_type" {
  description = "Academy-permitted x86_64 type; confirm permission and quota before apply."
  type        = string
  default     = "t3.micro"
  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small", "t3a.micro", "t3a.small"], var.instance_type)
    error_message = "Select a small x86_64 type from the list and confirm Academy permits it."
  }
}

variable "ami_id" {
  description = "Ubuntu 24.04 x86_64 AMI permitted in the region; null looks up Canonical's official image."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.ami_id == null ? true : can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must be null or an AMI identifier, not a key or name."
  }
}

variable "message" {
  description = "Public demonstration message; never enter secrets."
  type        = string
  default     = "Hello from AWS and UPC"
  validation {
    condition     = length(var.message) >= 1 && length(var.message) <= 120
    error_message = "The public message must contain between 1 and 120 characters."
  }
}

variable "bucket_name" {
  description = "New, globally available S3 name; null generates a name with a random suffix persisted in state."
  type        = string
  default     = null
  validation {
    condition = var.bucket_name == null ? true : (
      can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name)) &&
      !can(regex("^(xn--|sthree-|amzn-s3-demo-)|(-s3alias|--ol-s3|\\.mrap|--x-s3|--table-s3)$", var.bucket_name))
    )
    error_message = "Use null or an S3 name of 3–63 lowercase letters/digits/hyphens, with alphanumeric ends and no reserved prefixes/suffixes."
  }
}
