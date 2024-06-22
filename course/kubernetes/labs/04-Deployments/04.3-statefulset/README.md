### MySQL StatefulSet

```
kubectl apply -f mysql-sts.yaml
```

```
kubectl get -n default pvc,pv,storageclass
```

### Ephemeral Containers

```
kubectl debug pod/mysql-0 --image=mysql -ti -- mysql -h 127.0.0.1 -padmin
```

### Check for issues

```
kubectl describe pod mysql-0
```

### Deploy a wordpress with a PVC

```
kubectl apply -f wordpress-deployment.yaml
```

### Get the wordpress load balancer

```
kubectl get svc wordpress
```

### Cleanup

```
kubectl delete -f .
```