variable "state_bucket" { type = string }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "name" {
  type    = string
  default = "wp-multi-stack"
}
variable "database_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "mysql_engine_version" {
  type    = string
  default = "8.4.11"
}
