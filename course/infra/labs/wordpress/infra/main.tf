data "aws_availability_zones" "available" {
  state = "available"
}


resource "random_id" "name" {
  byte_length = 3
}

locals {
  name        = "infra-lab-wp-${var.lab_id}-${random_id.name.hex}"
  short_name  = "infra-lab-wp-${substr(var.lab_id, 0, 10)}-${random_id.name.hex}"
  tls_enabled = var.domain_name != null && var.hosted_zone_id != null
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.53.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
  lifecycle {
    precondition {
      condition     = (var.domain_name == null) == (var.hosted_zone_id == null)
      error_message = "Supply both domain_name and hosted_zone_id, or neither."
    }
    precondition {
      condition     = length(data.aws_availability_zones.available.names) >= 2
      error_message = "This lab needs two available Availability Zones."
    }
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = cidrsubnet(aws_vpc.lab.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = cidrsubnet(aws_vpc.lab.cidr_block, 8, count.index + 10)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-private-${count.index + 1}" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = local.name }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = local.name }
}

resource "aws_nat_gateway" "lab" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = local.name }
  depends_on    = [aws_internet_gateway.lab]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
  tags = { Name = "${local.name}-public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab.id
  }
  tags = { Name = "${local.name}-private" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Only the selected client can reach the ALB"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "${local.name}-alb" }
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "Private WordPress: HTTP from ALB, no SSH"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "${local.name}-app" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.client_cidr
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  count             = local.tls_enabled ? 1 : 0
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.client_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "alb" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "web" {
  for_each          = { http = 80, https = 443 }
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
}

resource "aws_vpc_security_group_egress_rule" "dns" {
  for_each          = toset(["tcp", "udp"])
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "${cidrhost(aws_vpc.lab.cidr_block, 2)}/32"
  ip_protocol       = each.value
  from_port         = 53
  to_port           = 53
}

resource "aws_iam_role" "app" {
  name = local.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = local.name
  role = aws_iam_role.app.name
}

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private[0].id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  user_data_replace_on_change = true
  user_data                   = <<-USERDATA
    #!/bin/bash
    set -euo pipefail
    umask 022
    dnf install -y httpd git php8.3 php8.3-cli php8.3-fpm php8.3-mysqlnd php8.3-process php8.3-mbstring php8.3-xml php8.3-gd php8.3-opcache awscli-2 jq
    install -d -m 0755 /opt/infra-lab
    git clone --no-checkout https://github.com/raelga/kubernetes-talks.git /opt/infra-lab/repository
    git -C /opt/infra-lab/repository checkout --detach '${var.repository_ref}'
    APP=/opt/infra-lab/repository/course/infra/labs/wordpress/app
    install -d -m 0750 -o root -g apache /etc/infra-lab
    curl -fsSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /etc/infra-lab/global-bundle.pem
    chmod 0644 /etc/infra-lab/global-bundle.pem
    cp /etc/infra-lab/global-bundle.pem /etc/pki/ca-trust/source/anchors/rds-global-bundle.pem
    update-ca-trust
    curl -fsSL https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar -o /usr/local/bin/wp
    echo 'ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c  /usr/local/bin/wp' | sha256sum --check
    chmod 0755 /usr/local/bin/wp
    wp core download --allow-root --path="$APP/public" --version='${var.wordpress_version}' --locale=en_US
    wp core verify-checksums --allow-root --path="$APP/public" --version='${var.wordpress_version}' --locale=en_US
    chown -R root:apache "$APP"
    find "$APP" -type d -exec chmod 0755 {} +
    find "$APP" -type f -exec chmod 0644 {} +
    install -d -m 0755 -o apache -g apache "$APP/public/wp-content/uploads"
    ln -s /etc/infra-lab/wp-config.php "$APP/wp-config.php"
    cat > /etc/httpd/conf.d/wordpress.conf <<'APACHE'
    <VirtualHost *:80>
      DocumentRoot /opt/infra-lab/repository/course/infra/labs/wordpress/app/public
      <Directory /opt/infra-lab/repository/course/infra/labs/wordpress/app/public>
        Require all granted
        AllowOverride None
        Options -Indexes +FollowSymLinks
        DirectoryIndex index.php
        RewriteEngine On
        RewriteCond /etc/infra-lab/configured !-f
        RewriteRule ^(?!health\.php$|readiness\.php$|ready\.php$) /ready.php [END]
        RewriteCond %%{REQUEST_FILENAME} !-f
        RewriteCond %%{REQUEST_FILENAME} !-d
        RewriteRule . /index.php [END]
      </Directory>
      <FilesMatch "^(wp-config\.php|\.ht)">
        Require all denied
      </FilesMatch>
    </VirtualHost>
    APACHE
    printf 'expose_php=Off\ndisplay_errors=Off\nlog_errors=On\n' > /etc/php.d/99-infra-lab.ini
    systemctl enable --now amazon-ssm-agent php-fpm httpd
  USERDATA
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags                  = { Name = local.name }
  }
  tags = { Name = local.name }
  depends_on = [
    aws_route_table_association.private,
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.ssm,
    aws_vpc_security_group_egress_rule.web,
    aws_vpc_security_group_egress_rule.dns
  ]
}

resource "aws_lb" "app" {
  name               = local.short_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  tags               = { Name = local.name }
}

resource "aws_lb_target_group" "app" {
  name     = local.short_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab.id
  health_check {
    path                = "/health.php"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = local.tls_enabled ? "redirect" : "forward"
    target_group_arn = local.tls_enabled ? null : aws_lb_target_group.app.arn
    dynamic "redirect" {
      for_each = local.tls_enabled ? [1] : []
      content {
        host        = var.domain_name
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_acm_certificate" "app" {
  count             = local.tls_enabled ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.tls_enabled ? {
    for option in aws_acm_certificate.app[0].domain_validation_options : option.domain_name => option
  } : {}
  zone_id         = var.hosted_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = false
}

resource "aws_acm_certificate_validation" "app" {
  count                   = local.tls_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

resource "aws_lb_listener" "https" {
  count             = local.tls_enabled ? 1 : 0
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.app[0].certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_route53_record" "app" {
  count           = local.tls_enabled ? 1 : 0
  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = false
  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

data "aws_rds_engine_version" "mysql" {
  count   = var.enable_database ? 1 : 0
  engine  = "mysql"
  version = var.mysql_engine_version
}

resource "aws_security_group" "database" {
  count       = var.enable_database ? 1 : 0
  name        = "${local.name}-database"
  description = "Private MySQL from the WordPress security group only"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "${local.name}-database" }
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  count                        = var.enable_database ? 1 : 0
  security_group_id            = aws_security_group.database[0].id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "database" {
  count                        = var.enable_database ? 1 : 0
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.database[0].id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

resource "aws_db_subnet_group" "app" {
  count      = var.enable_database ? 1 : 0
  name       = local.name
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = local.name }
}

resource "aws_db_instance" "app" {
  count                        = var.enable_database ? 1 : 0
  identifier                   = local.name
  engine                       = "mysql"
  engine_version               = data.aws_rds_engine_version.mysql[0].version
  instance_class               = var.database_instance_class
  allocated_storage            = 20
  storage_type                 = "gp3"
  storage_encrypted            = true
  db_name                      = "wordpress"
  username                     = "labadmin"
  manage_master_user_password  = true
  db_subnet_group_name         = aws_db_subnet_group.app[0].name
  vpc_security_group_ids       = [aws_security_group.database[0].id]
  publicly_accessible          = false
  multi_az                     = false
  backup_retention_period      = 0
  deletion_protection          = false
  skip_final_snapshot          = true
  delete_automated_backups     = true
  auto_minor_version_upgrade   = true
  copy_tags_to_snapshot        = false
  performance_insights_enabled = false
  tags                         = { Name = local.name }
}

resource "aws_iam_role_policy" "database_secret" {
  count = var.enable_database ? 1 : 0
  name  = "wordpress-master-bootstrap"
  role  = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_db_instance.app[0].master_user_secret[0].secret_arn
    }]
  })
}
