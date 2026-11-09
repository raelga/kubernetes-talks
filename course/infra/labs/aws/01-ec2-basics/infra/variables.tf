variable "aws_region" {
  description = "AWS deployment region."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "ssh_cidr" {
  description = "IPv4 CIDR allowed to access SSH; web access stays public."
  type        = string
  default     = "0.0.0.0/0"
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.ssh_cidr))
    error_message = "Use a valid IPv4 CIDR, such as 0.0.0.0/0 or your public IP followed by /32."
  }
}

variable "key_name" {
  description = "Existing EC2 SSH key pair; Academy provides vockey."
  type        = string
  default     = "vockey"
  nullable    = false
}

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

