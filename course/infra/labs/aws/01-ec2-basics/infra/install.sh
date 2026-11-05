#!/bin/bash
set -euo pipefail
exec > >(tee -a /var/log/infra-lab-bootstrap.log /dev/console) 2>&1
repository_ref="$1"
echo 'Installing Apache and Git'
dnf install -y httpd git
mkdir -p /opt/infra-lab
git init /opt/infra-lab/repository
git -C /opt/infra-lab/repository remote add origin https://github.com/raelga/kubernetes-talks.git
git -C /opt/infra-lab/repository fetch --depth=1 origin "$repository_ref"
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
