## Hello Job

### Deploy 1 jobs with 5 executions

```
kubectl apply -f job-5.yaml
```

```
kubectl get pods -l app=hello
```

### Deploy manually job several times

! Check the Downward API implementation

```
kubectl apply -f job-manual.yaml
```

Raises an error due to the `generateName` usage.

```
kubectl create -f job-manual.yaml
```

```
kubectl get pods -l app=hello
```

### Schedule a job

```
kubectl apply -f cronjob.yaml
```

```
kubectl get pods -l app=hello -w
```

```
k logs -l app=hello --ignore-errors
```

### Cleanup

```
kubectl delete all -l app=hello
```
