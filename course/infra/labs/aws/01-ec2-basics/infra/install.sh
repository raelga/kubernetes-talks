#!/bin/bash
set -euo pipefail

# Send installation output to the log file and EC2 system console.
exec > >(tee -a /var/log/infra-lab-bootstrap.log /dev/console) 2>&1

repository_ref='${repository_ref}'
lab_dir=/opt/infra-lab
repo_dir="$lab_dir/repository"
app_dir="$repo_dir/course/infra/labs/aws/01-ec2-basics/app"

# Install the web server and Git.
echo 'Installing Apache and Git'
dnf install -y httpd git

# Check out the requested version of the application.
mkdir -p "$lab_dir"
git init "$repo_dir"
git -C "$repo_dir" remote add origin https://github.com/raelga/kubernetes-talks.git
git -C "$repo_dir" fetch --depth=1 origin "$repository_ref"
git -C "$repo_dir" checkout --detach FETCH_HEAD
commit="$(git -C "$repo_dir" rev-parse HEAD)"

# Publish the hostname and commit displayed on the demo page.
test -f "$app_dir/index.html"
test -f "$app_dir/health"
printf '{"hostname":"%s","commit":"%s"}\n' \
  "$(hostname)" "$commit" > "$app_dir/runtime.json"

# Allow Apache to read the checked-out files, including on SELinux systems.
chmod -R a+rX "$app_dir"
if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
  chcon -R -t httpd_sys_content_t "$app_dir"
fi

# Serve the application directly from the repository checkout.
cat > /etc/httpd/conf.d/infra-lab.conf <<APACHE
DocumentRoot "$app_dir"
<Directory "$app_dir">
    Options -Indexes +FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
ServerTokens Prod
ServerSignature Off
APACHE

# Start Apache now and enable it on future boots.
systemctl enable --now httpd
echo "Application ready from commit $commit"
