#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

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
