#!/usr/bin/env bash
# Prepare the tools and repository only; never provision infrastructure.
set -euo pipefail

terraform_version="1.13.3"
repo_dir="${HOME}/kubernetes-talks"
bin_dir="${HOME}/.local/bin"

for tool in curl git unzip install mktemp uname; do
  command -v "$tool" >/dev/null || { printf 'Required tool not found: %s\n' "$tool" >&2; exit 1; }
done
if ! command -v sha256sum >/dev/null && ! command -v shasum >/dev/null; then
  printf 'Required tool not found: sha256sum or shasum\n' >&2
  exit 1
fi
if [[ -e "$repo_dir" && ! -e "$repo_dir/.git" ]]; then
  printf 'Refusing to overwrite an existing non-Git path: %s\n' "$repo_dir" >&2
  exit 1
fi

case "$(uname -s)" in
  Linux) platform="linux" ;;
  Darwin) platform="darwin" ;;
  *) printf 'Supported systems: Linux and macOS.\n' >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64) architecture="amd64" ;;
  aarch64|arm64) architecture="arm64" ;;
  *) printf 'Supported architectures: x86_64 and arm64.\n' >&2; exit 1 ;;
esac

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
archive="terraform_${terraform_version}_${platform}_${architecture}.zip"
release_url="https://releases.hashicorp.com/terraform/${terraform_version}"
curl -fsSL "${release_url}/${archive}" -o "${work_dir}/${archive}"
curl -fsSL "${release_url}/terraform_${terraform_version}_SHA256SUMS" -o "${work_dir}/SHA256SUMS"
expected=""
while read -r checksum filename; do
  if [[ "$filename" == "$archive" ]]; then
    expected="$checksum"
    break
  fi
done < "${work_dir}/SHA256SUMS"
if command -v sha256sum >/dev/null; then
  actual="$(sha256sum "${work_dir}/${archive}")"
else
  actual="$(shasum -a 256 "${work_dir}/${archive}")"
fi
if [[ -z "$expected" || "${actual%% *}" != "$expected" ]]; then
  printf 'Terraform archive checksum verification failed.\n' >&2
  exit 1
fi
unzip -q "${work_dir}/${archive}" -d "$work_dir"
install -d "$bin_dir"
install -m 755 "${work_dir}/terraform" "${bin_dir}/terraform"

if [[ -e "$repo_dir/.git" ]]; then
  printf 'Existing checkout preserved without pulling or resetting: %s\n' "$repo_dir"
else
  git clone --depth=1 --branch main https://github.com/raelga/kubernetes-talks.git "$repo_dir"
fi

"${bin_dir}/terraform" version
printf '\nRepository: %s\n' "$repo_dir"
printf 'Lab: %s/course/infra/labs/terraform-intro\n' "$repo_dir"
printf 'No directory change, Terraform initialization or cloud deployment was performed.\n'
