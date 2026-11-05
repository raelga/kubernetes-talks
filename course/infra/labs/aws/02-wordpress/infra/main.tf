data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

resource "random_id" "name" {
  byte_length = 3
}

locals {
  name        = "infra-lab-wp-${var.lab_id}-${random_id.name.hex}"
  short_name  = "infra-lab-wp-${substr(var.lab_id, 0, 10)}-${random_id.name.hex}"
  tls_enabled = var.domain_name != null && var.hosted_zone_id != null
}

