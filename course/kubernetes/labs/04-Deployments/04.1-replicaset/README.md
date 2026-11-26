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

List the Pods. Their names are derived from the ReplicaSet name; their placement depends on the cluster and scheduler:

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
kubectl delete pod "$(kubectl get pods -l app=cats --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"
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

The Service uses `NodePort` 30080. With the [Kind configuration](../../00-Kind/README.md), that port is mapped to `localhost:8080`:

```sh
kubectl get svc cats
```

```
NAME   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
cats   NodePort   10.96.141.244   <none>        80:30080/TCP   5s
```

Open <http://localhost:8080> in your browser (or `curl`) — you should get an `HTTP 200` and a page showing a cat:

```sh
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/
```

```
200
```

If Kind runs on a remote EC2 instance with that configuration, forward port 8080 through SSH from your laptop before opening the URL in your laptop browser:

```sh
ssh -o IdentitiesOnly=yes -i /path/to/terraform-k8s.pem -L 8080:localhost:8080 ec2-user@<EC2_IP>
```

Keep the SSH tunnel running. Other labs use the same NodePort; clean up their Services before starting this example.

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

The `cats` selector is broad (`app=cats`), so it overlaps both specific selectors. Existing Pods owned by a ReplicaSet are not adopted by another, and each controller creates its own replicas. The Service selects all ready Pods with `app=cats`, regardless of their owner. Unowned matching Pods can be adopted by either matching ReplicaSet, however, so avoid overlapping selectors in real workloads.

### Cleanup

```sh
kubectl delete -f lia-rs.yaml -f liam-rs.yaml
kubectl delete -f cats-replicaset.yaml -f service.yaml
```

Or remove everything labelled `app=cats` in one shot:

```sh
kubectl delete all -l app=cats
```

## Observe Service routing as ReplicaSets change

`routing-demo.yaml` creates two ReplicaSets with distinct selectors, one Service
selecting both versions, and a fixed client Pod that makes a new HTTP request
every second. Each server responds with its version and **Pod hostname**, not
the Kubernetes node name. Distribution is not guaranteed to be even.
The Service uses NodePort 30081, available at `http://localhost:8081/` with
the [kind configuration](../../00-Kind/README.md). Delete other Services using
30081 first; the cats Service uses 30080 and can run alongside it.


```sh
kubectl apply -f routing-demo.yaml
kubectl wait --for=condition=Ready pod -l app=routing-demo --timeout=120s
kubectl wait --for=condition=Ready pod/routing-client --timeout=120s
kubectl get rs,pods -l app=routing-demo -o wide
kubectl get endpointslices -l kubernetes.io/service-name=routing-demo
kubectl logs -f routing-client
```

Keep the logs open and use a second terminal. Add the green replicas:

```sh
kubectl scale rs/routing-green --replicas=2
kubectl wait --for=condition=Ready pod -l app=routing-demo,version=green --timeout=120s
kubectl get endpointslices -l kubernetes.io/service-name=routing-demo
```

The same client can now receive blue or green responses. Scale blue to zero:

```sh
kubectl scale rs/routing-blue --replicas=0
kubectl get rs,pods -l app=routing-demo -o wide
kubectl get endpointslices -l kubernetes.io/service-name=routing-demo
```

After endpoint and routing updates converge, new requests go to green Pods.
Scaling blue back up adds it again. If all replicas are scaled to zero, the
client logs connection failures or timeouts until a backend returns.
`kubectl port-forward service/routing-demo` selects one Pod and does not show
this Service routing behavior.

Stop following logs with Ctrl-C, then delete the example:

```sh
kubectl delete -f routing-demo.yaml
```
