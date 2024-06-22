### MySQL Deployment

```
kubectl apply -f mysql-deployment.yaml
```

### Check for issues

```
kubectl describe pod -l app=mysql
```

### Deploy secret

```
kubectl apply -f mysql-credentials-secret.yaml
```

### Deploy a wordpress with a PVC

```
kubectl apply -f wordpress-deployment.yaml
```

### Get the wordpress load balancer

```
kubectl get svc wordpress
```

### Delete the mysql pod

```
kubectl delete pod -l app=mysql
```

### Check the app

(All MySQL backed data is gone)

### Deploy MySQl with a PVC

```
kubectl apply -f mysql-deployment.yaml
```

### Delete the pod

```
kubectl delete pod -l app=mysql
```

### Check the app

MySQL data persists in the PVC and is attached to the new pod

### Cleanup

```
kubectl delete -f .
```
