# Blue/green deployment for multiple services

This scenario releases new versions of services A and B together. A single
Ingress is the traffic switch, so clients never need different service URLs.

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

## Deploy version 1

Run all remaining commands from this directory:

```bash
kubectl apply -f app-a-v1.yaml -f app-b-v1.yaml -f ingress-v1.yaml
kubectl rollout status deployment/my-app-a-v1 --timeout=5m
kubectl rollout status deployment/my-app-b-v1 --timeout=5m
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

Keep the port-forward running in a separate terminal:

```bash
kubectl port-forward service/ingress-nginx-controller \
  -n ingress-nginx 8080:80
```

In the scenario terminal, set the URL:

```bash
export INGRESS_URL=http://127.0.0.1:8080
```

Verify that both hosts use version 1:

```bash
curl -H 'Host: a.domain.com' "$INGRESS_URL"
curl -H 'Host: b.domain.com' "$INGRESS_URL"
```

## Stage and switch version 2

Create both green deployments and wait for both before changing the Ingress:

```bash
kubectl apply -f app-a-v2.yaml -f app-b-v2.yaml
kubectl rollout status deployment/my-app-a-v2 --timeout=5m
kubectl rollout status deployment/my-app-b-v2 --timeout=5m
kubectl apply -f ingress-v2.yaml

curl -H 'Host: a.domain.com' "$INGRESS_URL"
curl -H 'Host: b.domain.com' "$INGRESS_URL"
```

Both responses should report `Version: v2.0.0`. Roll back atomically if either
service fails validation:

```bash
kubectl apply -f ingress-v1.yaml
```

To promote version 2, restore the v2 Ingress if necessary and remove version 1:

```bash
kubectl apply -f ingress-v2.yaml
kubectl delete -f app-a-v1.yaml -f app-b-v1.yaml
```

## Cleanup

```bash
kubectl delete -f ingress-v2.yaml -f ingress-v1.yaml \
  -f app-a-v2.yaml -f app-b-v2.yaml \
  -f app-a-v1.yaml -f app-b-v1.yaml --ignore-not-found
```
