#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  printf 'Usage: APP_EXAMPLE=local|shared %s AWS_CONTEXT AZURE_CONTEXT GCP_CONTEXT DIGITALOCEAN_CONTEXT\n' "$0" >&2
  exit 2
fi
example="${APP_EXAMPLE:-local}"
case "$example" in
  local|shared) app_name="guestbook" ;;
  *) printf 'APP_EXAMPLE must be local or shared.\n' >&2; exit 2 ;;
esac
contexts=("$@")
providers=(aws azure gcp digitalocean)
overlay_root="$(cd "$(dirname "$0")" && pwd)/overlays"
private_dir="$(mktemp -d)"
trap 'rm -rf "$private_dir"' EXIT
chmod 700 "$private_dir"
umask 077

# Render every overlay first: missing inputs fail before any cluster is changed.
# Shared datastore renders contain Secret data; never print them or save them in Git.
for provider in "${providers[@]}"; do
  kubectl kustomize "$overlay_root/$provider/$example" > "$private_dir/$provider.yaml"
done
for i in "${!contexts[@]}"; do
  printf '\n==> Applying %s YAML on %s (%s)\n' "$example" "${providers[$i]}" "${contexts[$i]}"
  kubectl --context "${contexts[$i]}" apply -f "$private_dir/${providers[$i]}.yaml"
done

rollout() {
  local context="$1"
  if [[ "$example" == local ]]; then
    kubectl --context "$context" -n default rollout status deployment/guestbook-local-redis --timeout=5m
  fi
  kubectl --context "$context" -n default rollout status "deployment/$app_name" --timeout=5m
}
rollout_pids=()
for context in "${contexts[@]}"; do rollout "$context" & rollout_pids+=("$!"); done
rollout_failed=0
for pid in "${rollout_pids[@]}"; do if ! wait "$pid"; then rollout_failed=1; fi; done
if [[ "$rollout_failed" -ne 0 ]]; then exit 1; fi

endpoints=("" "" "" "")
for attempt in {1..60}; do
  all_ready=1
  for i in "${!contexts[@]}"; do
    if [[ -z "${endpoints[$i]}" ]]; then
      endpoint=$(kubectl --context "${contexts[$i]}" -n default get service "$app_name" \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{" "}{.status.loadBalancer.ingress[0].ip}')
      endpoints[$i]="${endpoint%% *}"
      if [[ -z "${endpoints[$i]}" ]]; then endpoints[$i]="${endpoint#* }"; fi
    fi
    if [[ -z "${endpoints[$i]}" ]]; then all_ready=0; fi
  done
  if [[ "$all_ready" -eq 1 ]]; then break; fi
  sleep 10
done
for i in "${!providers[@]}"; do
  if [[ -z "${endpoints[$i]}" ]]; then
    printf 'Timed out waiting for the %s %s public load balancer.\n' "${providers[$i]}" "$example" >&2; exit 1
  fi
  printf '%s endpoint (%s): %s\n' "$example" "${providers[$i]}" "${endpoints[$i]}"
done
