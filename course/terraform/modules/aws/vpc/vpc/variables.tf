variable "region" {
  description = "EC2 region"
  type        = string
  default     = "eu-west-1"
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

variable "subnet-a" {
  description = "Subnet a CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet-b" {
  description = "Subnet b CIDR"
  type        = string
  default     = "10.0.2.0/24"
}
variable "subnet-c" {
  description = "Subnet c CIDR"
  type        = string
  default     = "10.0.3.0/24"
}
