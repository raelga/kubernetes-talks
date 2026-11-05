data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_partition" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name        = "infra-lab-ec2-${var.lab_id}-${random_id.suffix.hex}"
  tls_enabled = var.domain_name != null
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = local.name }
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

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
  tags = { Name = "${local.name}-public" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name}-nat" }
}

resource "aws_nat_gateway" "lab" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = local.name }
  depends_on    = [aws_internet_gateway.lab, aws_route_table_association.public]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab.id
  }
  tags = { Name = "${local.name}-private" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Client-only HTTP and optional HTTPS; egress only to the application"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "${local.name}-alb" }
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "HTTP only from the ALB; outbound package, Git and SSM access"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "${local.name}-app" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the authorized public IPv4 address"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.client_cidr
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  count             = local.tls_enabled ? 1 : 0
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the authorized public IPv4 address"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.client_cidr
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Application traffic and health checks"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Only the ALB can contact Apache"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_web" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.app.id
  description       = "Packages, public Git checkout and SSM through NAT"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_dns" {
  for_each          = toset(["tcp", "udp"])
  security_group_id = aws_security_group.app.id
  description       = "DNS within the VPC"
  ip_protocol       = each.value
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = aws_vpc.lab.cidr_block
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
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = local.name
  role = aws_iam_role.app.name
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private[0].id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  user_data_replace_on_change = true

  user_data = <<-USER_DATA
    #!/bin/bash
    set -euo pipefail
    exec > >(tee -a /var/log/infra-lab-bootstrap.log /dev/console) 2>&1
    echo 'Installing Apache, Git and the SSM agent'
    dnf install -y httpd git amazon-ssm-agent
    systemctl enable --now amazon-ssm-agent
    mkdir -p /opt/infra-lab
    git init /opt/infra-lab/repository
    git -C /opt/infra-lab/repository remote add origin https://github.com/raelga/kubernetes-talks.git
    git -C /opt/infra-lab/repository fetch --depth=1 origin ${jsonencode(var.repository_ref)}
    git -C /opt/infra-lab/repository checkout --detach FETCH_HEAD
    app=/opt/infra-lab/repository/course/infra/labs/aws/01-ec2-basics/app
    test -f "$app/index.html"
    test -f "$app/health"
    printf '{"hostname":"%s","commit":"%s"}\n' "$(hostname)" "$(git -C /opt/infra-lab/repository rev-parse HEAD)" > "$app/runtime.json"
    chmod -R a+rX "$app"
    if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
      chcon -R -t httpd_sys_content_t "$app"
    fi
    cat > /etc/httpd/conf.d/infra-lab.conf <<'APACHE'
    DocumentRoot "/opt/infra-lab/repository/course/infra/labs/aws/01-ec2-basics/app"
    <Directory "/opt/infra-lab/repository/course/infra/labs/aws/01-ec2-basics/app">
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ServerTokens Prod
    ServerSignature Off
    APACHE
    systemctl enable --now httpd
    echo "Application ready from commit $(git -C /opt/infra-lab/repository rev-parse HEAD)"
  USER_DATA

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
    tags                  = { Name = local.name, Stack = local.name }
  }

  tags = { Name = local.name }
  depends_on = [
    aws_route_table_association.private,
    aws_iam_role_policy_attachment.ssm,
    aws_vpc_security_group_egress_rule.app_web,
    aws_vpc_security_group_egress_rule.app_dns,
  ]
}

resource "aws_lb" "app" {
  name                       = "infra-lab-ec2-${random_id.suffix.hex}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  enable_deletion_protection = false
  drop_invalid_header_fields = true
  tags                       = { Name = local.name }
  depends_on                 = [aws_route_table_association.public]
}

resource "aws_lb_target_group" "app" {
  name                 = "infra-lab-ec2-${random_id.suffix.hex}"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.lab.id
  deregistration_delay = 10

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Name = local.name }
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
  tags              = { Name = local.name }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.tls_enabled ? {
    for option in aws_acm_certificate.app[0].domain_validation_options : option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  } : {}

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.value]
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
