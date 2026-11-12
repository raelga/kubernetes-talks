#!/bin/bash
set -Eeuo pipefail
exec > >(tee -a /var/log/upc-bootstrap.log) 2>&1
trap 'echo "Bootstrap failed at line $LINENO" >&2' ERR

hostnamectl set-hostname ${name}
echo "${tls_public_key}" >> /home/${system_user}/.ssh/authorized_keys

# Install dependencies and start Docker on this and subsequent boots.
yum install --assumeyes tree yum-utils git unzip nano vim openssl jq tar docker
systemctl enable --now docker
usermod -aG docker ${system_user}

yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum install --assumeyes terraform
printf 'alias tf=terraform\nalias k=kubectl\n' > /etc/profile.d/aliases.sh

# Pin downloads and verify them against the publisher's checksums.
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
cd "$workdir"
curl -fsSLo kubectl https://dl.k8s.io/release/v1.29.1/bin/linux/amd64/kubectl
curl -fsSLo kubectl.sha256 https://dl.k8s.io/release/v1.29.1/bin/linux/amd64/kubectl.sha256
printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum -c -
install -m 0755 kubectl /usr/local/bin/kubectl

curl -fsSLo kind-linux-amd64 https://kind.sigs.k8s.io/dl/v0.21.0/kind-linux-amd64
curl -fsSLo kind.sha256 https://kind.sigs.k8s.io/dl/v0.21.0/kind-linux-amd64.sha256sum
sha256sum -c kind.sha256
install -m 0755 kind-linux-amd64 /usr/local/bin/kind

curl -fsSLO https://get.helm.sh/helm-v3.17.3-linux-amd64.tar.gz
curl -fsSLO https://get.helm.sh/helm-v3.17.3-linux-amd64.tar.gz.sha256sum
sha256sum -c helm-v3.17.3-linux-amd64.tar.gz.sha256sum
tar -xzf helm-v3.17.3-linux-amd64.tar.gz
install -m 0755 linux-amd64/helm /usr/local/bin/helm

git clone --depth=1 https://github.com/raelga/kubernetes-talks.git /home/${system_user}/kubernetes-talks
chown -R ${system_user}:${system_user} /home/${system_user}/kubernetes-talks
shutdown -f now --reboot
