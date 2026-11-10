variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "name" {
  type    = string
  default = "wp-multi-stack"
}
variable "cidr_block" {
  type    = string
  default = "10.53.0.0/16"
}
variable "http_cidr" {
  description = "Client IPv4 CIDR allowed to reach the disposable HTTP site."
  type        = string
  default     = "0.0.0.0/0"
}
