resource "mysql_user" "wordpress" {
  user                = "wordpress_app"
  host                = "%"
  password_wo         = var.mysql_password
  password_wo_version = var.mysql_password_version
  tls_option          = "SSL"
}


resource "mysql_grant" "wordpress" {
  user     = mysql_user.wordpress.user
  host     = mysql_user.wordpress.host
  database = data.terraform_remote_state.infra.outputs.database_name
  table    = "*"
  grant    = false

  # WordPress installation, content and schema upgrades need only this database.
  privileges = [
    "SELECT",
    "INSERT",
    "UPDATE",
    "DELETE",
    "CREATE",
    "DROP",
    "ALTER",
    "INDEX",
  ]
}
