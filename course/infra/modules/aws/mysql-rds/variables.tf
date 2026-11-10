variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_security_group_id" { type = string }
variable "database_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "mysql_engine_version" {
  type    = string
  default = "8.4.11"
}
