#!/usr/bin/env bash
# kubelet v1.16 dockershim is incompatible with docker.io 26.x on Ubuntu 20.04.
set -euo pipefail

need_version="20.10.21-0ubuntu1~20.04.2"
current=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "none")

if [[ "$current" == 20.10.* ]]; then
  echo "Docker $current is OK for kubelet 1.16"
  exit 0
fi

echo "Downgrading Docker from $current to $need_version for kubelet 1.16..."

# Preseed docker.io postinst (otherwise apt would block on "Automatically restart Docker daemon?").
# NOTE: the real debconf key is "docker.io/restart" (not "docker.io/restart_docker").
echo "docker.io docker.io/restart boolean true" | sudo debconf-set-selections

# "< /dev/null" + "timeout" guarantee this never hangs an unattended/non-tty SSH session
# if a future docker.io version adds a new, unpreseeded debconf question.
timeout 120 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  "docker.io=${need_version}" < /dev/null

sudo systemctl restart docker
docker version
