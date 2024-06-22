Canary deployment using Kubernetes native functionnalities
==========================================================

> In the following example we apply the poor man's canary using Kubernetes
native features (replicas). If you want a finer grained control over traffic
shifting, check the [nginx-ingress](../nginx-ingress) example which use
[Nginx](http://nginx.org/) to split traffic or the [a/b testing](../../ab-testing)
example which shift traffic using [Istio](https://istio.io).

## Steps to follow

1. 10 replicas of version 1 is serving traffic
1. deploy 1 replicas version 2 (meaning ~10% of traffic)
1. wait enought time to confirm that version 2 is stable and not throwing
   unexpected errors
1. scale up version 2 replicas to 10
1. wait until all instances are ready
1. shutdown version 1

## In practice

## Steps to follow

1. version 1 is serving traffic
1. deploy version 2
1. wait until version 2 is ready
1. switch incoming traffic from version 1 to version 2
1. shutdown version 1

## In practice

### Deploy the first application

```
kubectl apply -f app-v1.yaml
kubectl get svc -w
```
### Test if the deployment was successful

```
curl "http://$(kubectl get svc my-app \
    -o jsonpath="{.status.loadBalancer.ingress[*]['ip']}")"
```

### To see the deployment in action, open a new terminal and run the following command

```
watch kubectl get pods
```

### Leave some requests to the service in the background

```
export APP_URL=$(kubectl get svc my-app \
    -o jsonpath="{.status.loadBalancer.ingress[*]['ip']}");
while sleep 0.5; do curl "http://${APP_URL}" --connect-timeout 5; done
```

! Keep this shell visible all the time.

### Then deploy version 2 of the application

```
kubectl apply -f app-v2.yaml
```

### Wait for all the version 2 pods to be running

```
kubectl rollout status deploy my-app-v2 -w
```

```
deployment "my-app-v2" successfully rolled out
```

### Side by side, 3 pods are running with version 2 but the service still send traffic to the first deployment.

# If necessary, you can manually test one of the pod by port-forwarding it to your local environment:

```
kubectl port-forward <name of pod> 8080:8080
```

Or by creating a second load balancer

```
kubectl apply -f svc-v2.yaml
kubectl get svc -w
```

### Test if the second deployment was successful

```
curl "http://$(kubectl get svc my-app-v2 \
    -o jsonpath="{.status.loadBalancer.ingress[*]['ip']}")"
```

### Once your are ready, you can switch the traffic to the new version by patching the service to send traffic to all pods with label version=v2.0.0

! Show the curl terminal before patching

```
kubectl patch service my-app -p '{"spec":{"selector":{"version":"v2.0.0"}}}'
```

### In case you need to rollback to the previous version

```
kubectl patch service my-app -p '{"spec":{"selector":{"version":"v1.0.0"}}}'
```

### If everything is working as expected, you can then delete the v1.0.0 deployment

```
kubectl delete deploy my-app-v1
```

### If everything is working as expected, you can then delete the v2.0.0 termporary load balancer

```
kubectl delete svc my-app-v2
```

### Check the remaining resources

```
kubectl get services,deployments,pods
```

### Cleanup

```bash
kubectl delete all -l app=my-app
```
