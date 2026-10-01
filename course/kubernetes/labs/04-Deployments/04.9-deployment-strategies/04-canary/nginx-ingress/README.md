# Canary deployment using ingress-nginx

This scenario uses ingress-nginx canary annotations to send 10% of requests to
version 2 while the primary Ingress continues to route to version 1.

## Prerequisites

Use an EKS or Kind cluster with `kubectl`, Helm 3, and `curl`. Install the shared
ingress-nginx controller if it is not already present:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx \
  --force-update
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace --version 4.15.1 --wait
kubectl rollout status deployment/ingress-nginx-controller \
  --namespace ingress-nginx --timeout=5m
```

The controller is shared cluster infrastructure. The cleanup below removes only
this scenario.

## Deploy both versions

Run all remaining commands from this directory:

```bash
kubectl apply -f app-v1.yaml -f ingress-v1.yaml
kubectl rollout status deployment/my-app-v1 --timeout=5m
kubectl apply -f app-v2.yaml
kubectl rollout status deployment/my-app-v2 --timeout=5m
```

### Access on EKS

Wait for the external hostname, then set the scenario URL:

```bash
kubectl get service ingress-nginx-controller -n ingress-nginx -w
export INGRESS_URL="http://$(kubectl get service ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

### Access on Kind

Keep this port-forward running in a separate terminal:

```bash
kubectl port-forward service/ingress-nginx-controller \
  -n ingress-nginx 8080:80
```

In the scenario terminal, set the URL:

```bash
export INGRESS_URL=http://127.0.0.1:8080
```

Confirm the primary Ingress serves only version 1:

```bash
for i in $(seq 1 10); do curl -s -H 'Host: my-app.com' "$INGRESS_URL"; done \
  | grep -o 'Version: v[0-9.]*' | sort | uniq -c
```

## Send 10% to the canary

Apply the second Ingress, whose canary annotations route 10% to the v2 Service:

```bash
kubectl apply -f ingress-v2-canary.yaml

for i in $(seq 1 100); do curl -s -H 'Host: my-app.com' "$INGRESS_URL"; done \
  | grep -o 'Version: v[0-9.]*' | sort | uniq -c
```

The result should contain both versions, with approximately 10 v2 responses.
To stop the canary immediately, remove only its Ingress:

```bash
kubectl delete -f ingress-v2-canary.yaml
```

## Promote version 2

Replace the primary route, verify that every response is v2, and remove v1:

```bash
kubectl apply -f ingress-v2.yaml

for i in $(seq 1 10); do curl -s -H 'Host: my-app.com' "$INGRESS_URL"; done \
  | grep -o 'Version: v[0-9.]*' | sort | uniq -c

kubectl delete -f app-v1.yaml
```

## Cleanup

```bash
kubectl delete -f ingress-v2-canary.yaml -f ingress-v2.yaml \
  -f ingress-v1.yaml -f app-v2.yaml -f app-v1.yaml --ignore-not-found
```
