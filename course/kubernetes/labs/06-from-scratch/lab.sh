#!/usr/bin/env bash
set -euo pipefail

# Keep the checkout and Terraform state between runs.
checkout="$HOME/kubernetes-talks-06"
if [[ -e "$checkout" ]]; then
  printf 'Checkout already exists: %s\nReuse its Terraform state rather than provisioning another instance.\n' "$checkout" >&2
  exit 1
fi

# Install the same Terraform version as the AWS Academy bootstrap.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL https://releases.hashicorp.com/terraform/1.12.1/terraform_1.12.1_linux_amd64.zip -o "$tmp/terraform.zip"
unzip -q "$tmp/terraform.zip" -d "$tmp"
mkdir -p "$HOME/.local/bin"
install -m 755 "$tmp/terraform" "$HOME/.local/bin/terraform"
export PATH="$HOME/.local/bin:$PATH"

# Provision only the instance; Kubernetes components are started manually.
git clone --depth=1 https://github.com/raelga/kubernetes-talks.git "$checkout"
cd "$checkout/course/kubernetes/labs/06-from-scratch"
terraform init -input=false
terraform apply -auto-approve -input=false
printf '\nSSH command (allow a few minutes for first-boot setup):\n'
terraform output -raw ssh_cmd
printf '\n\nKeep this checkout for cleanup. To destroy the instance:\n'
printf 'cd "%s/course/kubernetes/labs/06-from-scratch" && "%s/.local/bin/terraform" destroy\n' "$checkout" "$HOME"
