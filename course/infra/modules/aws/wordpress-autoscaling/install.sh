#!/bin/bash
set -Eeuo pipefail
umask 022

# Send installation output to the log file and EC2 system console.
exec > >(tee -a /var/log/infra-lab-bootstrap.log /dev/console) 2>&1

# Cloud-init and SSM may start together; only one installer can run at a time.
exec 9>/var/lock/infra-lab-install.lock
flock 9
step=initialization
trap 'echo "Installation failed during $step (line $LINENO)." >&2' ERR

download() {
  curl -fsSL --retry 3 --retry-max-time 180 --connect-timeout 10 --max-time 120 \
    "$1" --output "$2"
}

wordpress_version='${wordpress_version}'
wordpress_sha256='${wordpress_sha256}'
lab_dir=/opt/infra-lab
app_dir=/var/www/html
config_dir=/etc/infra-lab

# Install Apache, PHP and the Python runtime used for database provisioning.
step=packages
dnf install -y \
  httpd tar gzip cronie util-linux diffutils python3 python3-pip \
  php8.3 php8.3-cli php8.3-fpm php8.3-mysqlnd \
  php8.3-process php8.3-mbstring php8.3-xml php8.3-gd php8.3-opcache

install -d -m 0755 "$lab_dir" "$app_dir"
python3 -m venv "$lab_dir/venv"
"$lab_dir/venv/bin/pip" install 'boto3==1.35.99' 'PyMySQL==1.1.1'
install -d -m 0750 -o root -g apache "$config_dir"

# Store a native WordPress config outside the document root; it reads the
# atomically refreshed credentials file on each PHP request.
step=configuration
cat > "$config_dir/wp-config.php.new" <<'WORDPRESS_CONFIG'
${wordpress_config}
WORDPRESS_CONFIG
chown root:apache "$config_dir/wp-config.php.new"
chmod 0640 "$config_dir/wp-config.php.new"
mv "$config_dir/wp-config.php.new" "$config_dir/wp-config.php"
ln -sfn "$config_dir/wp-config.php" "$app_dir/wp-config.php"

fetcher=/usr/local/sbin/infra-lab-fetch-credentials
cat > "$fetcher" <<'FETCH_CREDENTIALS'
${fetch_credentials}
FETCH_CREDENTIALS
chown root:root "$fetcher"
chmod 0700 "$fetcher"
printf '*/1 * * * * root %s >/dev/null 2>&1\n' "$fetcher" > /etc/cron.d/infra-lab-wordpress-secret
chmod 0644 /etc/cron.d/infra-lab-wordpress-secret


# Trust the AWS RDS certificates for encrypted database connections.
step=certificates
download https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem "$config_dir/global-bundle.pem.new"
chmod 0644 "$config_dir/global-bundle.pem.new"
mv "$config_dir/global-bundle.pem.new" "$config_dir/global-bundle.pem"
cp "$config_dir/global-bundle.pem" /etc/pki/ca-trust/source/anchors/rds-global-bundle.pem
update-ca-trust

# Terraform creates the secret version; IAM, Secrets Manager and RDS may need
# time to converge. Cron continues retrying if the initial window expires.
step=database
database_ready=false
for attempt in {1..30}; do
  if "$fetcher" >/dev/null 2>&1; then
    database_ready=true
    break
  fi
  sleep 10
done
if [[ "$database_ready" != true ]]; then
  echo 'Database provisioning is not ready; cron will continue retrying.' >&2
fi


# Verify the pinned archive before changing any WordPress files.
step=wordpress
archive="$lab_dir/wordpress.tar.gz"
if ${require_seed}; then
  cp /opt/wordpress-image/wordpress.tar.gz "$archive"
else
  download "https://wordpress.org/wordpress-$wordpress_version.tar.gz" "$archive"
fi
echo "$wordpress_sha256  $archive" | sha256sum --check
tar -xzf "$archive" --strip-components=1 --no-same-owner --no-same-permissions \
  --exclude=wordpress/wp-content/uploads -C "$app_dir"
rm "$archive"

# The drift experiment deliberately permits local dashboard updates.
if ${allow_dashboard_updates}; then
  chown -R apache:apache "$app_dir"
fi
install -d -m 0755 -o apache -g apache "$app_dir/wp-content/uploads"

${media_setup}

# Serve WordPress directly, including its native setup and login screens.
step=apache
cat > /etc/httpd/conf.d/wordpress.conf <<APACHE
<VirtualHost *:80>
  DocumentRoot $app_dir
  <Directory $app_dir>
    Require all granted
    AllowOverride None
    Options -Indexes +FollowSymLinks
    DirectoryIndex index.php
    RewriteEngine On
    RewriteCond %%{REQUEST_FILENAME} !-f
    RewriteCond %%{REQUEST_FILENAME} !-d
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
step=services
systemctl enable --now amazon-ssm-agent php-fpm httpd crond
echo 'WordPress installation complete.'
