locals {
  fetch_credentials = templatefile("${path.module}/bootstrap-credentials.py.tftpl", {
    secret_arn       = aws_secretsmanager_secret.application.arn
    admin_secret_arn = var.master_secret_arn
    region           = data.aws_region.current.name
  })

  install_script = templatefile("${path.module}/install.sh", {
    wordpress_version = var.wordpress_version
    wordpress_sha256  = var.wordpress_sha256
    fetch_credentials = local.fetch_credentials
    wordpress_config  = file("${path.module}/wp-config.php.tftpl")
    require_seed      = var.ami_id != null
    media_setup = var.s3_bucket == "" ? "" : templatefile("${path.module}/media.sh.tftpl", {
      bucket = var.s3_bucket
      region = data.aws_region.current.name
    })
  })

  user_data_script = templatefile("${path.module}/user-data.sh.tftpl", {
    installer = local.install_script
  })
}
