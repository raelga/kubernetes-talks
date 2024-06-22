
### Hostname DaemonSet

```
kubectl apply -f hostname-ds.yaml
```

```
kubectl get pods -l app=hostname
```

```
kubectl get nodes
```

Rollout a new version with the DownwardAPI volume

```
kubectl apply -f hostname-dwapi-ds.yaml
```

```
kubectl get pods -l app=hostname -w
```

```
kubectl exec -ti $(kubectl get pods -l app=hostname -o name --field-selector=status.phase==Running | head -n1) -- /bin/bash
```

Check /etc/podinfo folder.
