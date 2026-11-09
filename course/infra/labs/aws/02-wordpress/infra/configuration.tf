locals {
  fetch_credentials = templatefile("${path.module}/fetch-credentials.sh.tftpl", {
    secret_arn = aws_secretsmanager_secret.application.arn
    region     = data.aws_region.current.name
  })

  install_script = templatefile("${path.module}/install.sh", {
    wordpress_version = var.wordpress_version
    wordpress_sha256  = var.wordpress_sha256
    fetch_credentials = local.fetch_credentials
    wordpress_config  = file("${path.module}/wp-config.php.tftpl")
  })

  user_data_script = templatefile("${path.module}/user-data.sh.tftpl", {
    installer = local.install_script
  })
}
