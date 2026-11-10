variable "state_bucket" { type = string }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "name" {
  type    = string
  default = "wp-split"
}
variable "instance_profile_name" {
  type    = string
  default = "LabInstanceProfile"
}
variable "instance_type" {
  type    = string
  default = "t4g.small"
}
variable "ssh_key_name" {
  description = "Existing EC2 key pair with a locally held private key."
  type        = string
  default     = "vockey"
}
variable "wordpress_version" {
  type    = string
  default = "7.1.4"
}
variable "wordpress_sha256" {
  type    = string
  default = "881e53a4681ff2cd911651b11cccdede5ae477ddf0765af5d6a1a8b219a1d835"
}
