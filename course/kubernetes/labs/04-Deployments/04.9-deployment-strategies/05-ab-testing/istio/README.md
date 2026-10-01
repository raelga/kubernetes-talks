# A/B testing using Istio

A/B testing routes selected requests to a new version according to a controlled
condition. This scenario demonstrates both a 90/10 weighted route and explicit
routing by the `X-API-Version` request header.

## Prerequisites and shared Istio installation

Use an EKS or Kind cluster with `kubectl`, Helm 3, and `curl`. Install Istio
1.30.5 once for the cluster if these shared releases are not already present:

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts \
  --force-update
helm repo update
helm upgrade --install istio-base istio/base \
  --namespace istio-system --create-namespace --version 1.30.5 --wait
helm upgrade --install istiod istio/istiod \
  --namespace istio-system --version 1.30.5 --wait
helm upgrade --install istio-ingress istio/gateway \
  --namespace istio-ingress --create-namespace --version 1.30.5 \
  --set labels.istio=ingressgateway --wait
kubectl rollout status deployment/istiod -n istio-system --timeout=5m
kubectl rollout status deployment/istio-ingress -n istio-ingress --timeout=5m
```

On EKS, enable cross-zone balancing and route only to nodes with a local gateway endpoint:

```bash
helm upgrade istio-ingress istio/gateway \
  --namespace istio-ingress --version 1.30.5 --reuse-values \
  --set service.externalTrafficPolicy=Local \
  --set-string 'service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled=true' \
  --wait
```

The control plane and ingress gateway are shared cluster infrastructure. This
scenario uses its own sidecar-injected namespace and cleanup removes only that
namespace.

## Deploy the applications and initial route

Run all remaining commands from this directory:

```bash
kubectl create namespace ab-testing-istio --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace ab-testing-istio istio-injection=enabled --overwrite
kubectl apply -n ab-testing-istio -f app-v1.yaml -f app-v2.yaml
kubectl rollout status deployment/my-app-v1 -n ab-testing-istio --timeout=5m
kubectl rollout status deployment/my-app-v2 -n ab-testing-istio --timeout=5m
kubectl apply -n ab-testing-istio -f gateway.yaml -f virtualservice.yaml
kubectl get pods -n ab-testing-istio
```

Each application Pod should show both the application and sidecar containers as
ready.

### Access on EKS

Wait for the gateway hostname, then set the scenario URL:

```bash
kubectl get service istio-ingress -n istio-ingress -w
export ISTIO_URL="http://$(kubectl get service istio-ingress \
  -n istio-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

### Access on Kind

Keep this port-forward running in a separate terminal:

```bash
kubectl port-forward service/istio-ingress -n istio-ingress 8080:80
```

In the scenario terminal, set the URL:

```bash
export ISTIO_URL=http://127.0.0.1:8080
```

Confirm that the initial route serves version 1:

```bash
curl -H 'Host: my-app.local' "$ISTIO_URL"
```

## Verify weighted routing

```bash
kubectl apply -n ab-testing-istio -f virtualservice-weight.yaml

for i in $(seq 1 100); do
  curl -s -H 'Host: my-app.local' "$ISTIO_URL"
done | grep -o 'Version: v[0-9.]*' | sort | uniq -c
```

The sample should be close to 90 v1 responses and 10 v2 responses.

## Verify header routing

```bash
kubectl apply -n ab-testing-istio -f virtualservice-match.yaml
curl -H 'Host: my-app.local' -H 'X-API-Version: v1.0.0' "$ISTIO_URL"
curl -H 'Host: my-app.local' -H 'X-API-Version: v2.0.0' "$ISTIO_URL"
```

The first response should report `Version: v1.0.0`; the second should report
`Version: v2.0.0`.

## Cleanup

```bash
kubectl delete namespace ab-testing-istio
```
