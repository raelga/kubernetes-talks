variable "region" {
  description = "EC2 region"
  type        = string
  default     = "us-east-1"
}

variable "cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "name" {
  description = "VPC name"
  type        = string
}

variable "public_subnet_a" {
  description = "Public Subnet AZ-a CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b" {
  description = "Public Subnet AZ-b CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "public_subnet_c" {
  description = "Public Subnet AZ-c CIDR"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_a" {
  description = "Private Subnet Az-a CIDR"
  type        = string
  default     = "10.0.4.0/24"
}

variable "private_subnet_b" {
  description = "Private Subnet Az-b CIDR"
  type        = string
  default     = "10.0.5.0/24"
}

variable "private_subnet_c" {
  description = "Private Subnet Az-c CIDR"
  type        = string
  default     = "10.0.6.0/24"
}
