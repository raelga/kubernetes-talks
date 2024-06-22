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

variable "tcp_allowed_ingress" {
  description = "EC2 SG TCP ingress open ports"
  type        = list(any)
  default     = [22, 8080, 8888, 9999]
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

variable "instance_role" {
  description = "EC2 "
  type        = string
  default     = "LabRole"
}

variable "system_default_user" {
  description = "EC2 instance default user"
  type        = string
  default     = "ubuntu"
}

variable "system_user" {
  description = "EC2 instance user"
  type        = string
  default     = "rael"
}
variable "github_user" {
  description = "GitHub user, to retrieve the public ssh keys"
  type        = string
  default     = "raelga"
}

variable "managed_ssh_key_name" {
  description = "AWS Managed SSH key, optional"
  type        = string
  default     = ""
}
