## Hostname DaemonSet

### Deploy the initial DaemonSet

```
kubectl apply -f hostname-ds.yaml
```

### Check pods

```
kubectl get pods -l app=hostname
```

```
kubectl logs -f -l app=hostname
```

```
kubectl get nodes
```

The number of pods equals the number of nodes

### Rollout a new version with the DownwardAPI volume

```
kubectl apply -f hostname-v2-ds.yaml
```

```
kubectl get pods -l app=hostname -w
```

```
kubectl exec -ti $(kubectl get pods -l app=hostname -o name --field-selector=status.phase==Running | head -n1) -- /bin/bash
```

Check /etc/podinfo folder.

### Cleanup

```
kubectl delete all -l app=hostname
```
