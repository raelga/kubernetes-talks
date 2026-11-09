#!/usr/bin/env bash
set -Eeuo pipefail

lab_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
infra_dir="$lab_dir/infra"
database_dir="$lab_dir/database"
state_lab="$lab_dir/../00-terraform-state/remote"

if [[ -z "${STATE_BUCKET:-}" ]]; then
  STATE_BUCKET="$(terraform -chdir="$state_lab" output -raw state_bucket_name)"
fi
export STATE_BUCKET TF_VAR_state_bucket="$STATE_BUCKET"
terraform -chdir="$infra_dir" init -input=false -backend-config="bucket=$STATE_BUCKET"
terraform -chdir="$database_dir" init -input=false -backend-config="bucket=$STATE_BUCKET"

# Delete the private SQL user before destroying RDS or its SSM tunnel target.
if [[ -n "$(terraform -chdir="$database_dir" state list)" ]]; then
  "$database_dir/with-ssm-tunnel.sh" destroy "$@"
fi
terraform -chdir="$infra_dir" destroy "$@"
