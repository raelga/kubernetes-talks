
### Hello Job

```
kubectl apply -f hello-5-job.yaml
```

```
kubectl get pods -l app=hello
```

! Check the Downward API implementation

```
kubectl apply -f hello-5-generated-job.yaml
```

```
kubectl create -f hello-5-generated-job.yaml
```

```
kubectl get pods -l app=hello
```

```
kubectl apply -f hello-cronjob.yaml
```

```
kubectl get pods -l app=hello
```

````
k logs -l app=hello --ignore-errors
```