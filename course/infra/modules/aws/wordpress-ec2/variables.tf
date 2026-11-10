variable "name" { type = string }
variable "subnet_id" { type = string }
variable "app_security_group_id" { type = string }
variable "ssh_security_group_id" { type = string }
variable "ssh_key_name" {
  type    = string
  default = "vockey"
}
variable "secret_arn" { type = string }
variable "master_secret_arn" { type = string }
variable "instance_profile_name" {
  type    = string
  default = "LabInstanceProfile"
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
