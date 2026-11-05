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
    APP=/opt/infra-lab/repository/course/infra/labs/aws/02-wordpress/app
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
      DocumentRoot /opt/infra-lab/repository/course/infra/labs/aws/02-wordpress/app/public
      <Directory /opt/infra-lab/repository/course/infra/labs/aws/02-wordpress/app/public>
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
