#!/bin/bash
set -euo pipefail
umask 022

# Send installation output to the log file and EC2 system console.
exec > >(tee -a /var/log/infra-lab-bootstrap.log /dev/console) 2>&1

repository_ref="$1"
wordpress_version="$2"
lab_dir=/opt/infra-lab
repo_dir="$lab_dir/repository"
app_dir="$repo_dir/course/infra/labs/aws/02-wordpress/app"
config_dir=/etc/infra-lab

# Install Apache, PHP and the tools used by WordPress configuration.
dnf install -y \
  httpd git awscli-2 jq \
  php8.3 php8.3-cli php8.3-fpm php8.3-mysqlnd \
  php8.3-process php8.3-mbstring php8.3-xml php8.3-gd php8.3-opcache

# Check out the application and its configuration helper.
install -d -m 0755 "$lab_dir"
git clone --no-checkout https://github.com/raelga/kubernetes-talks.git "$repo_dir"
git -C "$repo_dir" checkout --detach "$repository_ref"

# Trust the AWS RDS certificates for encrypted database connections.
install -d -m 0750 -o root -g apache "$config_dir"
curl -fsSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  -o "$config_dir/global-bundle.pem"
chmod 0644 "$config_dir/global-bundle.pem"
cp "$config_dir/global-bundle.pem" /etc/pki/ca-trust/source/anchors/rds-global-bundle.pem
update-ca-trust

# Install the pinned WP-CLI release and verify its checksum.
curl -fsSL https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar \
  -o /usr/local/bin/wp
echo 'ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c  /usr/local/bin/wp' \
  | sha256sum --check
chmod 0755 /usr/local/bin/wp

# Download official WordPress into Apache's document root.
wp core download --allow-root --path="$app_dir/public" \
  --version="$wordpress_version" --locale=en_US
wp core verify-checksums --allow-root --path="$app_dir/public" \
  --version="$wordpress_version" --locale=en_US

# Keep core files read-only to Apache; only uploads need write access.
chown -R root:apache "$app_dir"
find "$app_dir" -type d -exec chmod 0755 {} +
find "$app_dir" -type f -exec chmod 0644 {} +
install -d -m 0755 -o apache -g apache "$app_dir/public/wp-content/uploads"
ln -s "$config_dir/wp-config.php" "$app_dir/wp-config.php"

# Serve a database-not-configured page until the second deployment stage.
cat > /etc/httpd/conf.d/wordpress.conf <<APACHE
<VirtualHost *:80>
  DocumentRoot $app_dir/public
  <Directory $app_dir/public>
    Require all granted
    AllowOverride None
    Options -Indexes +FollowSymLinks
    DirectoryIndex index.php
    RewriteEngine On
    RewriteCond /etc/infra-lab/configured !-f
    RewriteRule ^(?!health\.php$|readiness\.php$|ready\.php$) /ready.php [END]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [END]
  </Directory>
  <FilesMatch "^(wp-config\.php|\.ht)">
    Require all denied
  </FilesMatch>
</VirtualHost>
APACHE

# Log PHP errors without showing them in browser responses.
printf 'expose_php=Off\ndisplay_errors=Off\nlog_errors=On\n' > /etc/php.d/99-infra-lab.ini

# Start the instance management agent, PHP and Apache.
systemctl enable --now amazon-ssm-agent php-fpm httpd
