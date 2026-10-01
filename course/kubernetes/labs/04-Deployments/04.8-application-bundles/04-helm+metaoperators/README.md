# Grafana Operator

This lab requires the Prometheus release from the previous lab in the `monitoring` namespace.

## Install the operator

```sh
helm upgrade --install grafana-operator \
  oci://ghcr.io/grafana-operator/helm-charts/grafana-operator \
  --namespace monitoring --create-namespace --version v5.0.0 \
  --wait --timeout=10m
```

Review the installed custom resources:

```sh
kubectl describe crd grafanas.grafana.integreatly.org
kubectl describe crd grafanadatasources.grafana.integreatly.org
kubectl describe crd grafanadashboards.grafana.integreatly.org
```

## Deploy Grafana

```sh
kubectl apply -f 00-grafana --namespace monitoring
kubectl wait -n monitoring --for=condition=Available \
  deployment/grafana-deployment --timeout=300s
```

On EKS, wait for the external hostname:

```sh
kubectl get service grafana-service -n monitoring -w
```

On Kind, use a port-forward:

```sh
kubectl port-forward -n monitoring service/grafana-service 3000:80
```

Log in with username `admin` and password `admin`. The Kubernetes API dashboard and Prometheus datasource are reconciled automatically by the operator.

```sh
kubectl get grafanas,grafanadatasources,grafanadashboards -n monitoring
```

## Cleanup

```sh
kubectl delete -f 00-grafana --namespace monitoring
helm uninstall grafana-operator --namespace monitoring
```