output "github_user" {
  value = var.github_user
}

output "system_user" {
  value = var.system_user
}

output "public_ip" {
  value = aws_eip.this.public_ip
}

output "terraform_private_key_path" {
  value     = local_file.private_key_file.filename
  sensitive = true
}
