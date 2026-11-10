variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "name" {
  type    = string
  default = "wp-modules"
}
variable "http_cidr" {
  description = "Client IPv4 CIDR allowed to reach HTTP and SSH."
  type        = string
  default     = "0.0.0.0/0"
}
variable "instance_profile_name" {
  type    = string
  default = "LabInstanceProfile"
}
variable "ssh_key_name" {
  description = "Existing EC2 key pair with a locally held private key."
  type        = string
  default     = "vockey"
}
