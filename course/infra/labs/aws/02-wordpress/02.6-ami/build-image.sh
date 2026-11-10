#!/bin/bash
set -Eeuo pipefail
[[ "$WORDPRESS_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$WORDPRESS_SHA256" =~ ^[a-f0-9]{64}$ ]]
sudo dnf install -y httpd tar gzip cronie util-linux diffutils python3 python3-pip \
  php8.3 php8.3-cli php8.3-fpm php8.3-mysqlnd php8.3-process \
  php8.3-mbstring php8.3-xml php8.3-gd php8.3-opcache
sudo install -d -m 0755 /opt/wordpress-image
curl -fsSL --retry 3 "https://wordpress.org/wordpress-$WORDPRESS_VERSION.tar.gz" -o /tmp/wordpress.tar.gz
echo "$WORDPRESS_SHA256  /tmp/wordpress.tar.gz" | sha256sum --check
sudo install -m 0644 /tmp/wordpress.tar.gz /opt/wordpress-image/wordpress.tar.gz
rm /tmp/wordpress.tar.gz
