# DaemonSet

A **DaemonSet** ensures that a copy of a Pod runs on **every node** (or a subset of nodes). As nodes join the cluster, the DaemonSet adds Pods to them; as nodes leave, those Pods are garbage-collected. This is the standard pattern for node-level agents:

- Log collectors (Fluentd, Filebeat)
- Monitoring agents (Node Exporter)
- CNI and kube-proxy networking
- Storage daemons

## Deploy the DaemonSet

The `hostname-ds.yaml` manifest runs a small Ubuntu container that prints its hostname every 10 seconds:

```sh
kubectl apply -f hostname-ds.yaml
kubectl rollout status ds/hostname
```

```
daemonset.apps/hostname created
daemon set "hostname" successfully rolled out
```

```sh
kubectl get ds hostname
```

```
NAME       DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
hostname   2         2         2       2            2           <none>          21s
```

There is **one Pod per node**, scheduled directly by the DaemonSet controller:

```sh
kubectl get pods -l app=hostname -o wide
```

```
NAME             READY   STATUS    RESTARTS   AGE   IP            NODE                NOMINATED NODE   READINESS GATES
hostname-4h4l6   1/1     Running   0          21s   10.244.2.22   labs-test-worker    <none>           <none>
hostname-5cgxx   1/1     Running   0          21s   10.244.1.20   labs-test-worker2   <none>           <none>
```

> ℹ️ On a 3-node Kind cluster `DESIRED` is **2**, not 3, because the control-plane node carries a `node-role.kubernetes.io/control-plane:NoSchedule` taint that the DaemonSet does not tolerate. Add a matching toleration (or run on a cluster without that taint) to also schedule there.

Check the logs across all DaemonSet Pods:

```sh
kubectl logs -l app=hostname --tail=1
```

```
DaemonSet running on hostname-4h4l6
DaemonSet running on hostname-5cgxx
```

## Rolling update with the Downward API

`hostname-v2-ds.yaml` updates the command and adds a **Downward API** volume that exposes the Pod's labels, annotations, and resource limits/requests as files. DaemonSets honour the `RollingUpdate` strategy:

```sh
kubectl apply -f hostname-v2-ds.yaml
kubectl rollout status ds/hostname
```

```
daemonset.apps/hostname configured
daemon set "hostname" successfully rolled out
```

Inspect the injected metadata inside one of the Pods:

```sh
POD=$(kubectl get pods -l app=hostname -o name | head -1)
kubectl exec $POD -- ls /etc/podinfo/
```

```
annotations
cpu_limit
cpu_request
labels
mem_limit
mem_request
```

The resource fields are converted using the `divisor` set in the manifest (CPU in milli-cores, memory in Mi):

```sh
kubectl exec $POD -- sh -c 'echo "cpu_limit=$(cat /etc/podinfo/cpu_limit) mem_limit=$(cat /etc/podinfo/mem_limit)Mi"'
```

```
cpu_limit=10 mem_limit=31Mi
```

### Cleanup

```sh
kubectl delete -f hostname-ds.yaml
```
