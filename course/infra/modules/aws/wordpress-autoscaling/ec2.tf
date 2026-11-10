data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-arm64"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
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

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name}-"
  image_id      = var.ami_id == null ? data.aws_ami.amazon_linux.id : var.ami_id
  instance_type = var.instance_type
  user_data     = base64encode(local.user_data_script)

  iam_instance_profile {
    name = data.aws_iam_instance_profile.app.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.app_security_group_id]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = local.name }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = local.name }
  }

}

resource "aws_autoscaling_group" "app" {
  name                      = local.name
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = var.public_subnet_ids
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 900

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }


  depends_on = [
    aws_vpc_security_group_ingress_rule.app,
    aws_vpc_security_group_egress_rule.alb,
    aws_lb_listener.http,
    aws_secretsmanager_secret_version.application
  ]
}
