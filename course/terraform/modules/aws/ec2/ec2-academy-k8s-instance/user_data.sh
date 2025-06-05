#!/bin/bash
# User configuration
curl -sq https://github.com/${github_user}.keys | tee -a /home/${system_user}/.ssh/authorized_keys
echo "${tls_private_key.terraform.public_key_openssh}" | tee -a /home/${var.system_user}/.ssh/authorized_keys
# Package installation
yum install --assumeyes tree yum-utils git unzip nano vim openssl jq
# Terraform
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo &&
  yum install --assumeyes terraform &&
  echo 'alias tf=terraform' | tee -a /etc/profile.d/aliases.sh
# Docker
yum install --assumeyes docker &&
  service docker start &&
  usermod -aG docker ${system_user}
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" &&
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl &&
  echo 'alias k=/usr/local/bin/kubectl' | tee -a /etc/profile.d/aliases.sh
# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.21.0/kind-linux-amd64 &&
  install -o root -g root -m 0755 kind /usr/local/bin/kind
#
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 >/tmp/get_helm.sh &&
  chmod 700 /tmp/get_helm.sh && /tmp/get_helm.sh && rm /tmp/get_helm.sh

# Repository
git clone --depth=1 https://github.com/raelga/kubernetes-talks.git /home/${system_user}/kubernetes-talks &&
  chown -R ${system_user}:${system_user} /home/${system_user}/kubernetes-talks

# Reboot
shutdown -f now --reboot
