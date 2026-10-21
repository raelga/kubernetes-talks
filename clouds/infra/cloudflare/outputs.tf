output "hostname" {
  description = "Cloudflare Worker custom domain for the global app."
  value       = cloudflare_workers_custom_domain.guestbook.hostname
}

output "router_script" {
  description = "Worker serving authenticated D1 state and routing UI/API traffic among cluster origins."
  value       = cloudflare_workers_script.router.script_name
}

output "state_api_url" {
  description = "STATE_API_URL for each Go app. The app adds /state/messages."
  value       = "https://${cloudflare_workers_custom_domain.guestbook.hostname}"
}

output "database_id" {
  description = "Shared Guestbook D1 database identifier."
  value       = cloudflare_d1_database.guestbook.id
}

output "database_name" {
  description = "Shared Guestbook D1 database name."
  value       = cloudflare_d1_database.guestbook.name
}

output "origin_hostnames" {
  description = "Worker origin hostnames, including Terraform-managed DNS aliases for IP endpoints."
  value       = local.origin_hostnames
}
