#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

DEFAULT_STORAGE_CLASS=$(kubectl get storageclass \
  -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

if [ -z "$DEFAULT_STORAGE_CLASS" ]; then
  echo "A default StorageClass is required for Prometheus persistence." >&2
  echo "Mark an appropriate StorageClass as default, then run this command again." >&2
  exit 1
fi

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
