# Scheduling: Affinity, Anti-Affinity, Taints & Tolerations

By default the Kubernetes scheduler places Pods on any node with enough resources. These features give you fine-grained control over **where** Pods land:

- **Node selectors / node affinity** — attract Pods to specific nodes.
- **Pod affinity** — co-locate Pods near each other.
- **Pod anti-affinity** — spread Pods apart (for high availability).
- **Taints & tolerations** — repel Pods from nodes unless they explicitly tolerate it.

> A multi-node cluster makes these labs meaningful. See the [top-level README](../README.md) for a 3-node Kind config.

## Part 1 — Node selector

`hostname-node-selector-deployment.yaml` pins its Pod to a node via `nodeSelector` on the built-in `kubernetes.io/hostname` label. It ships with a **placeholder** value, so the Pod is intentionally unschedulable at first:

```sh
kubectl apply -f hostname-node-selector-deployment.yaml
kubectl get pods -l app=hostname-node-selector
```

```
NAME                                      READY   STATUS    RESTARTS   AGE
hostname-node-selector-7bd5fc86fc-2npjx   0/1     Pending   0          5s
```

`describe` shows why — no node matches the selector:

```sh
kubectl describe pod -l app=hostname-node-selector | grep -A2 Events
```

```
  Warning  FailedScheduling  10s  default-scheduler  0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector.
```

List your real nodes and patch the Deployment to target one of them:

```sh
kubectl get nodes -o name
```

```
node/labs-test-control-plane
node/labs-test-worker
node/labs-test-worker2
```

```sh
NODE=labs-test-worker   # replace with one of your worker nodes
kubectl patch deployment hostname-node-selector \
  -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"$NODE\"}}}}}"
kubectl rollout status deployment/hostname-node-selector
```

The Pod now schedules onto the chosen node:

```sh
kubectl get pods -l app=hostname-node-selector -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name
```

```
NODE               NAME
labs-test-worker   hostname-node-selector-58b678d588-smpdk
```

## Part 2 — Pod affinity and anti-affinity

`hostname-affinity-deployment.yaml` uses **podAffinity** (3 replicas that prefer to sit together) and `hostname-antiaffinity-deployment.yaml` uses **podAntiAffinity** (3 replicas that prefer to spread). Both use `preferredDuringScheduling…` so they are soft preferences, not hard requirements.

```sh
kubectl apply -f hostname-affinity-deployment.yaml -f hostname-antiaffinity-deployment.yaml
kubectl rollout status deployment/hostname-affinity
kubectl rollout status deployment/hostname-anti-affinity
```

Look at the distribution:

```sh
kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name --sort-by=.spec.nodeName | grep affinity
```

```
labs-test-worker    hostname-anti-affinity-6b9fb6b989-69l4w
labs-test-worker    hostname-anti-affinity-6b9fb6b989-pfk8m
labs-test-worker2   hostname-affinity-5c679c5877-5hfcf
labs-test-worker2   hostname-affinity-5c679c5877-k8gtw
labs-test-worker2   hostname-affinity-5c679c5877-vdw4t
labs-test-worker2   hostname-anti-affinity-6b9fb6b989-2sgtq
```

The three **affinity** Pods all landed on the same node (co-located), while the **anti-affinity** Pods were spread across the available nodes (2 + 1, since there are only 2 schedulable workers for 3 replicas).

## Part 3 — Taints and tolerations

A **taint** marks a node as repelling Pods; a **toleration** lets a Pod ignore that taint. The `NoExecute` effect even **evicts** running Pods that don't tolerate it.

Pick the busiest node and taint it:

```sh
TOP_NODE=$(kubectl get pod -o=custom-columns=NODE:.spec.nodeName --no-headers \
  | grep -v '<none>' | sort | uniq -c | sort -r | awk '{print $2}' | head -n1)
echo "$TOP_NODE"
kubectl taint nodes ${TOP_NODE} area=vip:NoExecute
```

```
labs-test-worker2
node/labs-test-worker2 tainted
```

The Pods that were running there are evicted and rescheduled (or go `Pending` if the other nodes are full):

```sh
kubectl get pods -o wide -l app=hostname-affinity
```

```
NAME                                 READY   STATUS    NODE
hostname-affinity-5c679c5877-855qg   0/1     Pending   <none>
hostname-affinity-5c679c5877-cnbl6   0/1     Pending   <none>
hostname-affinity-5c679c5877-hxq4x   0/1     Pending   <none>
```

Now deploy `hostname-toleration-deployment.yaml`, whose Pods **tolerate** `area=vip:NoExecute` — they are allowed back onto the tainted node:

```sh
kubectl apply -f hostname-toleration-deployment.yaml
kubectl get pods -l app=hostname-tolerations -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name
```

```
NODE                NAME
labs-test-worker2   hostname-tolerations-596699cb6-2zn9s
labs-test-worker2   hostname-tolerations-596699cb6-rl7dn
labs-test-worker    hostname-tolerations-596699cb6-8d9ht
```

The toleration Pods can schedule onto `labs-test-worker2` even though it is tainted.

### Cleanup

```sh
kubectl delete -f .
kubectl taint nodes ${TOP_NODE} area=vip:NoExecute-
```

## Scheduling rules at a glance

| Method | Direction | Strength | Use case |
|--------|-----------|----------|----------|
| Node selector | Attract to node | Hard | Simple node targeting |
| Node affinity | Attract to node | Hard or soft | Expressive node rules |
| Pod affinity | Attract to pods | Hard or soft | Co-location |
| Pod anti-affinity | Repel from pods | Hard or soft | High availability |
| Taint / toleration | Repel from node | Hard | Dedicated / specialised nodes |
