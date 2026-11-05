resource "aws_ssm_association" "configure_wordpress" {
  count = var.enable_database ? 1 : 0
  name  = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app.id]
  }

  parameters = {
    commands = join("\n", [
      "set -e",
      "cloud-init status --wait",
      join(" ", [
        "php /opt/infra-lab/repository/course/infra/labs/aws/02-wordpress/app/configure.php",
        "--endpoint ${jsonencode(aws_db_instance.app[0].address)}",
        "--secret-arn ${jsonencode(aws_db_instance.app[0].master_user_secret[0].secret_arn)}",
        "--database ${jsonencode(aws_db_instance.app[0].db_name)}",
        "--region ${jsonencode(data.aws_region.current.name)}",
        "--site-url ${jsonencode(local.tls_enabled ? "https://${var.domain_name}" : "http://${aws_lb.app.dns_name}")}",
      ]),
    ])
  }

  wait_for_success_timeout_seconds = 600

  depends_on = [
    aws_db_instance.app,
    aws_vpc_security_group_ingress_rule.database,
    aws_vpc_security_group_egress_rule.database,
  ]
}
