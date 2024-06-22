A/B testing deployment using GKE ingress functionnalities
==========================================================

> In the following example we apply the poor man's A/B testing using GKE
native ingress controller (host/path based routing).
> If you want a finer grained control over traffic
shifting, check the [istio](../istio) example.

## Steps to follow

1. version 1 is serving traffic
1. deploy load balancer with v1
1. deploy version 2
1. wait until version 2 is ready
1. update load balancer with both v1 and v2
1. validate the service
1. update load balancer with v2
1. shutdown v1

## In practice

### Deploy the first application

```
kubectl apply -f app-v1.yaml
kubectl get svc -w
```

### Deploy the v1 only ingress

```
kubectl apply -f ingress-v1.yaml
```

### Test if the deployment was successful

```
kubectl get ingress -w
```

### To see the deployment in action, open a new terminal and run the following command

```
watch kubectl get pods
```

### Leave some requests to the service in the background

```
export APP_URL=$(kubectl get ingress my-app \
    -o jsonpath="{.status.loadBalancer.ingress[*]['ip']}");
while sleep 0.5; do curl "http://${APP_URL}" --connect-timeout 5 --header 'Host: my-app.rael.io'; done
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

### Side by side, 5 pods are running with version 2 but the ingress still sends traffic to the first v1.

If necessary, you can manually test one of the pod by port-forwarding it to your local environment:

```
kubectl port-forward svc/my-app-v2 8080:80
```

### Update the ingress to include v2 with a custom host header

```
kubectl apply -f ingress-ab.yaml
```

### Test if the second deployment was successful

```
curl "http://$(kubectl get ingress my-app \
    -o jsonpath="{.status.loadBalancer.ingress[*]['ip']}")" --header 'Host: v2.my-app.rael.io'
```

### Once your are ready, you can switch the traffic to the new version by patching the service to send traffic to all pods with label version=v2.0.0

! Show the curl terminal before patching

```
kubectl apply -f ingress-v2.yaml
```

### In case you need to rollback to the previous version

```
kubectl apply -f ingress-v1.yaml
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
