variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "allowed_http_cidr" {
  description = "Client IPv4 CIDR allowed to reach the disposable HTTP site."
  type        = string
  default     = "0.0.0.0/0"
  validation {
    condition     = can(cidrnetmask(var.allowed_http_cidr))
    error_message = "Provide a valid IPv4 CIDR."
  }
}
variable "instance_profile_name" {
  description = "Existing profile with permission to read this lab's Secrets Manager secret."
  type        = string
  default     = "LabInstanceProfile"
}
variable "instance_type" {
  type    = string
  default = "t4g.small"
}
variable "wordpress_version" {
  type    = string
  default = "7.1.4"
}
variable "wordpress_sha256" {
  type    = string
  default = "881e53a4681ff2cd911651b11cccdede5ae477ddf0765af5d6a1a8b219a1d835"
}
