variable "name" { type = string }
variable "cidr_block" {
  type    = string
  default = "10.53.0.0/16"
}
variable "http_cidr" {
  description = "Client IPv4 CIDR allowed to reach HTTP and single-instance SSH."
  type        = string
  default     = "0.0.0.0/0"
}
