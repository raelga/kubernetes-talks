#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required." >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  if ! command -v wget >/dev/null 2>&1; then
    echo "wget is required to install Helm." >&2
    exit 1
  fi

  HELM_INSTALLER=$(mktemp)
  trap 'rm -f "$HELM_INSTALLER"' 0 HUP INT TERM
  wget -qO "$HELM_INSTALLER" \
    https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
  bash "$HELM_INSTALLER"
  rm -f "$HELM_INSTALLER"
  trap - 0 HUP INT TERM
fi

DEFAULT_STORAGE_CLASS=$(kubectl get storageclass \
  -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

if [ -z "$DEFAULT_STORAGE_CLASS" ]; then
  for STORAGE_CLASS in gp2 standard; do
    if kubectl get storageclass "$STORAGE_CLASS" >/dev/null 2>&1; then
      kubectl annotate storageclass "$STORAGE_CLASS" \
        storageclass.kubernetes.io/is-default-class=true --overwrite
      DEFAULT_STORAGE_CLASS=$STORAGE_CLASS
      break
    fi
  done
fi

if [ -z "$DEFAULT_STORAGE_CLASS" ]; then
  echo "No default, gp2, or standard StorageClass is available." >&2
  echo "Mark an appropriate StorageClass as default, then run this command again." >&2
  exit 1
fi

echo "Using default StorageClass: $DEFAULT_STORAGE_CLASS"

helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts --force-update
helm repo update

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace --wait

helm upgrade --install grafana-operator \
  oci://ghcr.io/grafana-operator/helm-charts/grafana-operator \
  --namespace monitoring --version v5.0.0 --wait

kubectl apply -f "$SCRIPT_DIR/grafana.yaml"
kubectl apply -f "$SCRIPT_DIR/deployments-dashboard.yaml"
kubectl rollout status deployment/grafana-deployment \
  --namespace monitoring --timeout=5m
