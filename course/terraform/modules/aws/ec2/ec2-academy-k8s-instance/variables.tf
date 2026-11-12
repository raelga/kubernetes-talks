variable "name" {
  description = "EC2 instance name"
  type        = string
}

variable "az" {
  description = "EC2 availability zone id"
  type        = string
  default     = "us-east-1a"
}

variable "vpc" {
  description = "EC2 VPC"
  type        = string
}

variable "subnet" {
  description = "EC2 VPC Subnet"
  type        = string
}


variable "instance_profile_name" {
  description = "Existing instance profile, or null for no profile."
  type        = string
  default     = null
}
variable "tcp_allowed_ingress" {
  description = "EC2 SG TCP ingress open ports"
  type        = list(any)
  default     = [22, 8080, 8888, 9999]
}

variable "ingress_cidr" {
  description = "Public IPv4 CIDR allowed to reach the lab."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.ingress_cidr))
    error_message = "Provide a valid IPv4 CIDR."
  }
}

variable "ami" {
  description = "EC2 instance AMI"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 Instance type"
  type        = string
  default     = "t3a.large"
}


variable "system_default_user" {
  description = "EC2 instance default user"
  type        = string
  default     = "ec2-user"
}

variable "system_user" {
  description = "EC2 instance user"
  type        = string
  default     = "ec2-user"
}

variable "managed_ssh_key_name" {
  description = "AWS Managed SSH key, optional"
  type        = string
  default     = ""
}
