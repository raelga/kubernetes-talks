# ReplicaSet

### Deploy the version of the application

```
kubectl apply -f cats.yaml
```

### Expose it as a service

```
kubectl apply -f service.yaml
```

### Test if the deployment was successful

```

curl "http://$(kubectl get svc cats \
 -o jsonpath="{.status.loadBalancer.ingress[*]['hostname']}")"

```

### To see the deployment in action, open a new terminal and run the following command

```
watch kubectl get pods
```

### Then deploy lia version of the application

```
kubectl apply -f lia.yaml;
watch kubectl get pods;
```

### Then deploy liam version of the application

```
kubectl apply -f liam.yaml
watch kubectl get pods;
```

### Cleanup

```bash
kubectl delete all -l app=cats
```
