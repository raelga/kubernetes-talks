Ramped deployment
=================

> Version B is slowly rolled out and replacing version A. Also known as
rolling-update or incremental.

![kubernetes ramped deployment](grafana-ramped.png)

The ramped deployment strategy consists of slowly rolling out a version of an
application by replacing instances one after the other until all the instances
are rolled out. It usually follows the following process: with a pool of version
A behind a load balancer, one instance of version B is deployed. When the
service is ready to accept traffic, the instance is added to the pool. Then, one
instance of version A is removed from the pool and shut down.

Depending on the system taking care of the ramped deployment, you can tweak the
following parameters to increase the deployment time:

- Parallelism, max batch size: Number of concurrent instances to roll out.
- Max surge: How many instances to add in addition of the current amount.
- Max unavailable: Number of unavailable instances during the rolling update
  procedure.

## Steps to follow

1. version 1 is serving traffic
1. deploy version 2
1. wait until all replicas are replaced with version 2

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
# If you can also pause the rollout if you want to run the application for a subset of users

```
kubectl rollout pause deploy my-app
```

# Then if you are satisfied with the result, resume rollout

```
kubectl rollout resume deploy my-app
```

### In case you discover some issue with the new version, you can undo the rollout

```
kubectl rollout undo deploy my-app
```

### Cleanup

```bash
kubectl delete all -l app=my-app
```
