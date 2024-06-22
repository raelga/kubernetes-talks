## Create a service account for the pod

```
kubectl apply -f serviceaccount.yaml
```

## Create a pod using the service account to fetch API information

```
kubectl apply -f pod.yaml
```

## Create a Role to allow read only operations to Pod resources

```
kubectl apply -f role.yaml
```


## Create a RoleBiding to the service account to inherit the role permissions

```
kubectl apply -f rolebinding.yaml
```

## Review the logs

```
❯ k logs -f service-account-pod
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
    "name": "service-account-pod",
    "namespace": "default",
    ...
```

## Delete the role

```
k delete -f rolebinding.yaml
````

```
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods \"service-account-pod\" is forbidden: User \"system:serviceaccount:default:service-account-pod-read\" cannot get resource \"pods\" in API group \"\" in the namespace \"default\"",
  "reason": "Forbidden",
  "details": {
    "name": "service-account-pod",
    "kind": "pods"
  },
  "code": 403
  ...
```