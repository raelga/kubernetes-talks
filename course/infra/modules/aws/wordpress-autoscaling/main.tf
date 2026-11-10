data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "random_id" "name" {
  byte_length = 3
}

locals {
  name          = "infra-lab-wpa-${var.lab_id}-${random_id.name.hex}"
  short_name    = "infra-lab-wpa-${substr(var.lab_id, 0, 10)}-${random_id.name.hex}"
  database_name = "wp_asg_${replace(var.lab_id, "-", "_")}"
  database_user = "wp_asg_${replace(var.lab_id, "-", "_")}"
  tls_enabled   = var.domain_name != null && var.hosted_zone_id != null
}
