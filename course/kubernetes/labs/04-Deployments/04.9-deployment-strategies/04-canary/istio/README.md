# Canary deployment using Istio

This scenario uses an Istio VirtualService to route 90% of requests to version
1 and 10% to version 2. Unlike replica weighting, the route weights are explicit.

## Prerequisites and shared Istio installation

Use an EKS or Kind cluster with `kubectl`, Helm 3, and `curl`. The HPA resources
in this scenario require a working metrics-server; verify it before continuing:

```bash
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

Install Istio 1.30.5 once for the cluster if these shared releases are not
already present:

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

On EKS, make the classic load balancer route only to nodes with a local gateway endpoint and enable cross-zone balancing:

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

## Deploy the canary

Run all remaining commands from this directory:

```bash
kubectl create namespace canary-istio --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace canary-istio istio-injection=enabled --overwrite
kubectl apply -n canary-istio -f app-v1.yaml -f app-v2.yaml
kubectl rollout status deployment/my-app-v1 -n canary-istio --timeout=5m
kubectl rollout status deployment/my-app-v2 -n canary-istio --timeout=5m
kubectl apply -n canary-istio -f hpa.yaml -f istio.yaml
kubectl get pods -n canary-istio
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

## Verify and change the route

Count a request sample. It should be close to 90 v1 responses and 10 v2
responses:

```bash
for i in $(seq 1 100); do curl -s "$ISTIO_URL"; done \
  | grep -o 'Version: v[0-9.]*' | sort | uniq -c
kubectl get hpa -n canary-istio
```

Route weights are at `spec.http[].route[].weight`. To promote v2, edit the
VirtualService and set the v1 weight to `0` and the v2 weight to `100`:

```bash
kubectl edit virtualservice/my-app -n canary-istio

for i in $(seq 1 20); do curl -s "$ISTIO_URL"; done \
  | grep -o 'Version: v[0-9.]*' | sort | uniq -c
```

Only `Version: v2.0.0` should remain. If load is generated for long enough,
observe HPA decisions with:

```bash
kubectl get hpa -n canary-istio -w
```

## Cleanup

```bash
kubectl delete namespace canary-istio
```
