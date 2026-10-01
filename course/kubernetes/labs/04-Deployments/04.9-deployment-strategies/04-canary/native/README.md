# Canary deployment using native Kubernetes replicas

This scenario approximates weighted traffic without an ingress controller. The
Service selects both versions, so endpoint counts determine their expected
shares: 10 version 1 replicas and 1 version 2 replica send about 1 in 11 requests
to version 2.

## Deploy the baseline and canary

Run these commands from this directory:

```bash
kubectl apply -f app-v1.yaml
kubectl rollout status deployment/my-app-v1 --timeout=5m
kubectl apply -f app-v2.yaml
kubectl rollout status deployment/my-app-v2 --timeout=5m
kubectl get deployment my-app-v1 my-app-v2
```

The deployments should report 10 ready v1 replicas and 1 ready v2 replica.
Replica weighting is approximate: kube-proxy balances connections rather than
enforcing an exact request percentage, and persistent connections can skew the
result.

## Platform-neutral verification from inside the cluster

Create a short-lived client Pod and count response versions:

```bash
kubectl run canary-client --rm -i --restart=Never \
  --image=curlimages/curl:8.17.0 -- \
  sh -c 'for i in $(seq 1 110); do curl -s http://my-app; done' \
  | grep -o 'Version: v[0-9.]*' | sort | uniq -c
```

Both versions should appear, with substantially fewer v2 responses.

## Access on EKS

Wait for the Service load-balancer hostname, then send a request:

```bash
kubectl get service my-app -w
export MY_APP_URL="http://$(kubectl get service my-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
curl "$MY_APP_URL"
```

## Access on Kind

Keep this port-forward running in a separate terminal:

```bash
kubectl port-forward service/my-app 8080:80
```

Then access the application from the scenario terminal:

```bash
export MY_APP_URL=http://127.0.0.1:8080
curl "$MY_APP_URL"
```

## Scale and promote

Scale version 2 to match version 1. The in-cluster verification should then show
an approximately even split:

```bash
kubectl scale deployment/my-app-v2 --replicas=10
kubectl rollout status deployment/my-app-v2 --timeout=5m

kubectl run canary-client --rm -i --restart=Never \
  --image=curlimages/curl:8.17.0 -- \
  sh -c 'for i in $(seq 1 100); do curl -s http://my-app; done' \
  | grep -o 'Version: v[0-9.]*' | sort | uniq -c
```

Promote v2 by removing v1 endpoints, verify that only v2 responds, and then
remove the old deployment:

```bash
kubectl scale deployment/my-app-v1 --replicas=0
kubectl rollout status deployment/my-app-v1 --timeout=5m

kubectl run canary-client --rm -i --restart=Never \
  --image=curlimages/curl:8.17.0 -- \
  sh -c 'for i in $(seq 1 20); do curl -s http://my-app; done' \
  | grep -o 'Version: v[0-9.]*' | sort | uniq -c

kubectl delete deployment/my-app-v1
```

Before deleting v1, rollback remains possible with:

```bash
kubectl scale deployment/my-app-v1 --replicas=10
kubectl scale deployment/my-app-v2 --replicas=1
```

## Cleanup

```bash
kubectl delete -f app-v2.yaml -f app-v1.yaml --ignore-not-found
```
