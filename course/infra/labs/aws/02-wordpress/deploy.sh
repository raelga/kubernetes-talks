#!/usr/bin/env bash
set -Eeuo pipefail
if [[ -n "${TF_LOG:-}" ]]; then
  echo "Unset TF_LOG: MySQL-provider debug output can expose connection details." >&2
  exit 2
fi
for option in "$@"; do
  case "$option" in
    -auto-approve|-input=false) ;;
    *) echo "Use TF_VAR_* environment variables; supported apply options are -auto-approve and -input=false." >&2; exit 2 ;;
  esac
done


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
terraform -chdir="$infra_dir" apply "$@"

region="$(terraform -chdir="$infra_dir" output -raw aws_region)"
endpoint="$(terraform -chdir="$infra_dir" output -raw database_endpoint)"
database_name="$(terraform -chdir="$infra_dir" output -raw database_name)"
instance_id="$(terraform -chdir="$infra_dir" output -raw instance_id)"

# Cloud-init runs only once. If a transient bootstrap failure was recorded,
# retry the saved idempotent installer on the same SSM-managed instance.
recovery_command='if ! cloud-init status --wait --long; then /opt/infra-lab/install.sh; fi'
recovery_parameters="$(python3 -c 'import json,sys; print(json.dumps({"commands":[sys.argv[1]]}))' "$recovery_command")"
recovery_id="$(aws ssm send-command --region "$region" --instance-ids "$instance_id" \
  --document-name AWS-RunShellScript --parameters "$recovery_parameters" \
  --query 'Command.CommandId' --output text)"
if ! aws ssm wait command-executed --region "$region" --command-id "$recovery_id" --instance-id "$instance_id"; then
  : # Inspect the structured status below without printing command output.
fi
recovery_status="$(aws ssm get-command-invocation --region "$region" \
  --command-id "$recovery_id" --instance-id "$instance_id" \
  --query Status --output text)"
if [[ "$recovery_status" != Success ]]; then
  echo "WordPress bootstrap recovery failed (SSM status: $recovery_status)." >&2
  exit 1
fi
application_secret_arn="$(terraform -chdir="$infra_dir" output -raw application_secret_arn)"

# Generate the app credential once, outside Terraform state. Reuse it on retries.
python3 "$database_dir/ensure-app-secret.py" \
  "$application_secret_arn" "$region" "$endpoint" "$database_name"

"$database_dir/with-ssm-tunnel.sh" apply -input=false "$@"
printf '\nDeployment complete. WordPress setup: %s/wp-admin/install.php\n' \
  "$(terraform -chdir="$infra_dir" output -raw application_url)"
printf 'The root cron refreshes credentials from Secrets Manager once per minute.\n'
