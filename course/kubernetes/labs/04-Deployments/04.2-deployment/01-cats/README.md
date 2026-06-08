# Deployment

A **Deployment** manages ReplicaSets and provides declarative updates for Pods. Instead of editing Pods directly, you describe the desired state and the Deployment controller changes the actual state at a controlled rate. It adds the features a bare ReplicaSet lacks:

- **Rolling updates** — replace Pods gradually with zero downtime.
- **Rollback** — revert to a previous revision if something breaks.
- **Revision history** — every change is recorded.

The `cats.yaml` manifest defines a Deployment of **5 replicas** with a `RollingUpdate` strategy (`maxSurge: 2`, `maxUnavailable: 1`).

## Deploy the application

```sh
kubectl apply -f cats.yaml -f service.yml
```

```
deployment.apps/cats created
service/cats created
```

Watch the rollout finish:

```sh
kubectl rollout status deployment/cats
```

```
Waiting for deployment "cats" rollout to finish: 0 of 5 updated replicas are available...
deployment "cats" successfully rolled out
```

A Deployment creates a ReplicaSet, which in turn creates the Pods. Note the ReplicaSet name includes a hash of the Pod template:

```sh
kubectl get deployment,rs -l app=cats
```

```
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cats   5/5     5            5           16s

NAME                              DESIRED   CURRENT   READY   AGE
replicaset.apps/cats-64645d55c7   5         5         5       16s
```

## Access the application

On Kind, reach the `LoadBalancer` Service through a port-forward:

```sh
kubectl port-forward svc/cats 8080:80
```

```sh
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/
```

```
200
```

Open <http://localhost:8080> to see the cat. Press `Ctrl+C` to stop the port-forward.

## Rolling update

Updating the image rolls out a new ReplicaSet while scaling down the old one. In a second terminal, watch the Pods:

```sh
kubectl get pods -l app=cats -w
```

Apply the `lia` version (`raelga/cats:lia`):

```sh
kubectl apply -f lia.yaml
```

```
deployment.apps/cats configured
```

```sh
kubectl rollout status deployment/cats
```

```
Waiting for deployment "cats" rollout to finish: 2 out of 5 new replicas have been updated...
Waiting for deployment "cats" rollout to finish: 1 old replicas are pending termination...
deployment "cats" successfully rolled out
```

Because of `maxSurge: 2` / `maxUnavailable: 1`, Kubernetes brings up to 2 extra Pods at a time and never drops more than 1 below the desired count — so the app stays available throughout. The page should now show a different cat.

## Revision history & rollback

Every applied change creates a revision:

```sh
kubectl rollout history deployment/cats
```

```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

Roll back to the previous revision (back to `blanca`):

```sh
kubectl rollout undo deployment/cats
kubectl rollout status deployment/cats
```

```
deployment.apps/cats rolled back
deployment "cats" successfully rolled out
```

Confirm the image reverted:

```sh
kubectl get pods -l app=cats -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
```

```
raelga/cats:blanca
```

> 💡 Tip: add `--record` (deprecated) or set a `kubernetes.io/change-cause` annotation to populate the `CHANGE-CAUSE` column, e.g.
> `kubectl annotate deployment/cats kubernetes.io/change-cause="deploy lia" --overwrite`.

### Cleanup

```sh
kubectl delete all -l app=cats
```
