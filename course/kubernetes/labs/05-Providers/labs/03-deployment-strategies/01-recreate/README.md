Recreate deployment
===================

> Version A is terminated then version B is rolled out.

![kubernetes recreate deployment](grafana-recreate.png)

The recreate strategy is a dummy deployment which consists of shutting down
version A then deploying version B after version A is turned off. This technique
implies downtime of the service that depends on both shutdown and boot duration
of the application.

## Steps to follow

1. version 1 is service traffic
1. delete version 1
1. deploy version 2
1. wait until all replicas are ready

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

### Leave some requests to the service in the background

```
export APP_URL=$(kubectl get svc my-app \
    -o jsonpath="{.status.loadBalancer.ingress[*]['ip']}");
while sleep 0.5; do curl "http://${APP_URL}" --connect-timeout 1; done
```

### To see the deployment in action, open a new terminal and run the following command

```
watch kubectl get pods
```

### Then deploy version 2 of the application

```
kubectl apply -f app-v2.yaml
```

### Cleanup

```bash
kubectl delete all -l app=my-app
```
