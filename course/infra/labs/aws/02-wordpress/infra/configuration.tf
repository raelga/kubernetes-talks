locals {
  install_script = templatefile("${path.module}/install.sh", {
    repository_ref    = var.repository_ref
    wordpress_version = var.wordpress_version
    wordpress_sha256  = var.wordpress_sha256
  })

  database_config = var.enable_database ? {
    endpoint   = aws_db_instance.app[0].address
    secret_arn = aws_db_instance.app[0].master_user_secret[0].secret_arn
    name       = aws_db_instance.app[0].db_name
    region     = data.aws_region.current.name
    site_url   = local.tls_enabled ? "https://${var.domain_name}" : "http://${aws_lb.app.dns_name}"
  } : null
}

resource "aws_ssm_association" "configure_wordpress" {
  name = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app.id]
  }

  parameters = {
    commands = templatefile("${path.module}/configure.sh.tftpl", {
      installer = local.install_script
      database  = local.database_config
    })
  }

  wait_for_success_timeout_seconds = 600

  depends_on = [
    aws_vpc_security_group_ingress_rule.database,
    aws_vpc_security_group_egress_rule.database,
  ]
}
