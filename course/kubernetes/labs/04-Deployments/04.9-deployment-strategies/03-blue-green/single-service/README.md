# Blue/green deployment for one service

Version 2 starts alongside version 1. After it is verified, one Service selector switches traffic atomically between the two deployments.

## Deploy the blue version

Run the commands from this directory:

```sh
kubectl apply -f app-v1.yaml -f service-v1.yaml
kubectl rollout status deployment/my-app-v1 --timeout=300s
```

On EKS:

```sh
kubectl get service my-app -w
APP_URL="http://$(kubectl get service my-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
curl "$APP_URL"
```

On Kind, keep a port-forward running in another terminal:

```sh
kubectl port-forward service/my-app 8080:80
```

Then use:

```sh
APP_URL=http://localhost:8080
curl "$APP_URL"
```

The response reports `Version: v1.0.0`.

## Deploy and verify the green version

```sh
kubectl apply -f app-v2.yaml -f service-internal-v2.yaml
kubectl rollout status deployment/my-app-v2 --timeout=300s
kubectl port-forward service/my-app-internal 8081:80
```

In another terminal, verify green directly:

```sh
curl http://localhost:8081
```

The response reports `Version: v2.0.0`, while `$APP_URL` still reports v1.

## Cut over and rollback

Switch the public Service to green:

```sh
kubectl patch service my-app \
  -p '{"spec":{"selector":{"version":"v2.0.0"}}}'
curl "$APP_URL"
```

Rollback is the inverse selector change:

```sh
kubectl patch service my-app \
  -p '{"spec":{"selector":{"version":"v1.0.0"}}}'
curl "$APP_URL"
```

After a successful cutover, point the Service to v2 again and remove v1:

```sh
kubectl patch service my-app \
  -p '{"spec":{"selector":{"version":"v2.0.0"}}}'
kubectl delete deployment my-app-v1
```

## Cleanup

```sh
kubectl delete -f service-internal-v2.yaml --ignore-not-found
kubectl delete -f app-v2.yaml --ignore-not-found
kubectl delete service my-app --ignore-not-found
kubectl delete deployment my-app-v1 --ignore-not-found
```
