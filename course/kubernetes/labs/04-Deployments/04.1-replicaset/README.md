# ReplicaSet

A **ReplicaSet** ensures that a specified number of identical Pod replicas are running at any time. If a Pod dies or is deleted, the ReplicaSet creates a replacement; if there are too many, it deletes the extras. It uses a **label selector** to decide which Pods it owns.

In practice you rarely create ReplicaSets directly — a [Deployment](../04.2-deployment/) manages them for you — but understanding them explains how Deployments work under the hood.

## Deploy the ReplicaSet

The `cats-replicaset.yaml` manifest requests **3 replicas** of the `raelga/cats:neu` web server, with readiness and liveness probes on port 80:

```sh
kubectl apply -f cats-replicaset.yaml
```

```
replicaset.apps/cats created
```

Check the ReplicaSet status:

```sh
kubectl get rs cats
```

```
NAME   DESIRED   CURRENT   READY   AGE
cats   3         3         3       20s
```

`DESIRED` is what you asked for, `CURRENT` is how many exist, and `READY` is how many pass their readiness probe.

List the Pods — note they are spread across the worker nodes and their names are derived from the ReplicaSet name:

```sh
kubectl get pods -l app=cats -o wide
```

```
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE                NOMINATED NODE   READINESS GATES
cats-72b9c   1/1     Running   0          30s   10.244.2.6   labs-test-worker    <none>           <none>
cats-qrzgr   1/1     Running   0          30s   10.244.1.6   labs-test-worker2   <none>           <none>
cats-xcj6w   1/1     Running   0          30s   10.244.2.5   labs-test-worker    <none>           <none>
```

## Self-healing

Delete one Pod and watch the ReplicaSet immediately recreate it to maintain 3 replicas:

```sh
kubectl delete pod -l app=cats --field-selector status.phase=Running --wait=false | head -1
kubectl get pods -l app=cats
```

```
NAME         READY   STATUS              RESTARTS   AGE
cats-72b9c   1/1     Running             0          90s
cats-qrzgr   1/1     Running             0          90s
cats-n4d8k   0/1     ContainerCreating   0          2s
```

The ReplicaSet noticed it was one Pod short and created a new one (`cats-n4d8k`).

## Expose the application

```sh
kubectl apply -f service.yaml
```

```
service/cats created
```

The Service is of type `LoadBalancer`. On a cloud provider this would get an external IP, but on **Kind** there is no cloud load balancer, so `EXTERNAL-IP` stays `<pending>`:

```sh
kubectl get svc cats
```

```
NAME   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
cats   LoadBalancer   10.96.141.244   <pending>     80:31996/TCP   5s
```

To reach the app locally, use `kubectl port-forward`:

```sh
kubectl port-forward svc/cats 8080:80
```

Then open <http://localhost:8080> in your browser (or `curl`) — you should get an `HTTP 200` and a page showing a cat:

```sh
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/
```

```
200
```

Press `Ctrl+C` to stop the port-forward.

## Selector overlap

The `lia-rs.yaml` and `liam-rs.yaml` manifests define two more ReplicaSets. Their Pods carry the same `app: cats` label (plus a `cat: lia` / `cat: liam` label), so they are all picked up by the `cats` Service:

```sh
kubectl apply -f lia-rs.yaml -f liam-rs.yaml
kubectl get rs -l app=cats
```

```
NAME   DESIRED   CURRENT   READY   AGE
cats   3         3         3       2m
lia    3         3         3       30s
liam   3         3         3       30s
```

Because each ReplicaSet has a **more specific** selector (`app=cats,cat=lia`), they only manage their own Pods and don't fight over each other's. The shared `app=cats` label means the Service now load-balances across all 9 Pods.

> ⚠️ Be careful with overlapping selectors. If two ReplicaSets had the *same* selector, they would each try to delete the other's "extra" Pods.

### Cleanup

```sh
kubectl delete -f lia-rs.yaml -f liam-rs.yaml
kubectl delete -f cats-replicaset.yaml -f service.yaml
```

Or remove everything labelled `app=cats` in one shot:

```sh
kubectl delete all -l app=cats
```
