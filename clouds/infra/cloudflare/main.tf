terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }
}

provider "cloudflare" {}

data "cloudflare_zones" "lab" {
  name = var.zone_name
  account = {
    id = var.account_id
  }
}

locals {
  state_credentials = sensitive(file("${path.module}/../../k8s/shared/credentials.env"))
  state_api_token   = one(regexall("(?m)^STATE_API_TOKEN=(\\S+)\\r?$", local.state_credentials))[0]

  ip_origins = {
    for cloud, address in var.origin_addresses : cloud => trimspace(address)
    if can(cidrhost("${trimspace(address)}/0", 0))
  }
  origin_hostnames = {
    for cloud, address in var.origin_addresses :
    cloud => try(cloudflare_dns_record.origin[cloud].name, trimspace(address))
  }
}

# Workers reject direct IP fetches. Address-scoped names avoid stale DNS when examples switch.
resource "cloudflare_dns_record" "origin" {
  for_each = local.ip_origins

  zone_id = data.cloudflare_zones.lab.result[0].id
  name    = "${each.key}-${substr(sha256(each.value), 0, 8)}.origin.${var.app_hostname}"
  type    = strcontains(each.value, ":") ? "AAAA" : "A"
  content = each.value
  ttl     = 60
  proxied = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_d1_database" "guestbook" {
  account_id = var.account_id
  name       = "clouds-guestbook"
}

resource "cloudflare_workers_script" "router" {
  account_id         = var.account_id
  script_name        = "clouds-global-router"
  content_file       = "${path.module}/../../app/router/worker.js"
  content_sha256     = filesha256("${path.module}/../../app/router/worker.js")
  main_module        = "worker.js"
  compatibility_date = "2026-10-20"
  bindings = [
    {
      name = "ORIGINS"
      type = "json"
      json = jsonencode(local.origin_hostnames)
    },
    {
      name        = "DB"
      type        = "d1"
      database_id = cloudflare_d1_database.guestbook.id
    },
    {
      name = "STATE_API_TOKEN"
      type = "secret_text"
      text = local.state_api_token
    },
  ]
}

resource "cloudflare_workers_custom_domain" "guestbook" {
  account_id = var.account_id
  hostname   = var.app_hostname
  service    = cloudflare_workers_script.router.script_name
  zone_id    = data.cloudflare_zones.lab.result[0].id
}
