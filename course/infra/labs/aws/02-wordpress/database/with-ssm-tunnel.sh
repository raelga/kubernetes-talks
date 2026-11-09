#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: with-ssm-tunnel.sh terraform-operation [arguments...]" >&2
  exit 2
fi
operation="$1"
shift

if [[ -n "${TF_LOG:-}" ]]; then
  echo "Unset TF_LOG: MySQL provider debug logs can expose connection credentials." >&2
  exit 2
fi
command -v aws >/dev/null
command -v session-manager-plugin >/dev/null || {
  echo "Install the AWS Session Manager plugin before deploying this private database lab." >&2
  exit 2
}

lab_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
infra_dir="$lab_dir/infra"
database_dir="$lab_dir/database"
region="$(terraform -chdir="$infra_dir" output -raw aws_region)"
endpoint="$(terraform -chdir="$infra_dir" output -raw database_endpoint)"
instance_id="$(terraform -chdir="$infra_dir" output -raw instance_id)"
application_secret_arn="$(terraform -chdir="$infra_dir" output -raw application_secret_arn)"
local_port="${SSM_LOCAL_PORT:-13306}"

for ((attempt = 0; attempt < 120; attempt++)); do
  if status="$(aws ssm describe-instance-information --region "$region" \
      --filters "Key=InstanceIds,Values=$instance_id" \
      --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)" \
      && [[ "$status" == Online ]]; then
    break
  fi
  if ((attempt == 119)); then
    echo "EC2 did not become SSM-online; inspect its bootstrap log and Academy permissions." >&2
    exit 1
  fi
  sleep 5
done

session_log="$(mktemp)"
proxy_log="$(mktemp)"
session_pid=''
proxy_pid=''
cleanup() {
  status=$?
  trap - EXIT INT TERM
  [[ -z "$proxy_pid" ]] || kill "$proxy_pid" 2>/dev/null || true
  [[ -z "$session_pid" ]] || kill "$session_pid" 2>/dev/null || true
  [[ -z "$proxy_pid" ]] || wait "$proxy_pid" 2>/dev/null || true
  [[ -z "$session_pid" ]] || wait "$session_pid" 2>/dev/null || true
  rm -f -- "$session_log" "$proxy_log"
  unset mysql_password mysql_password_version secret_json
  exit "$status"
}
trap cleanup EXIT INT TERM

parameters="$(python3 -c 'import json,sys; print(json.dumps({"host":[sys.argv[1]],"portNumber":["3306"],"localPortNumber":[sys.argv[2]]}))' "$endpoint" "$local_port")"
aws ssm start-session --region "$region" --target "$instance_id" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "$parameters" >"$session_log" 2>&1 < /dev/null &
session_pid=$!

python3 "$database_dir/socks5-forward.py" --allowed-host "$endpoint" \
  --forward-port "$local_port" >"$proxy_log" 2>&1 < /dev/null &
proxy_pid=$!

for ((attempt = 0; attempt < 60; attempt++)); do
  if ! kill -0 "$session_pid" 2>/dev/null || ! kill -0 "$proxy_pid" 2>/dev/null; then
    echo "Could not start the private RDS SSM tunnel; check Session Manager access and local ports." >&2
    exit 1
  fi
  if python3 -c 'import socket,sys; s=socket.create_connection(("127.0.0.1",int(sys.argv[1])),timeout=1); s.close()' 1080 2>/dev/null; then
    break
  fi
  if ((attempt == 59)); then
    echo "The local MySQL SOCKS proxy did not start; check whether port 1080 is already in use." >&2
    exit 1
  fi
  sleep 1
done
secret_json="$(aws secretsmanager get-secret-value --region "$region" \
  --secret-id "$application_secret_arn" --query SecretString --output text)"
mysql_password="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])' <<<"$secret_json")"
mysql_password_version="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["password_version"])' <<<"$secret_json")"
unset secret_json

TF_VAR_state_bucket="${STATE_BUCKET:?Export STATE_BUCKET before initializing the database backend.}" \
  TF_VAR_mysql_password="$mysql_password" \
  TF_VAR_mysql_password_version="$mysql_password_version" \
  terraform -chdir="$database_dir" "$operation" "$@"
