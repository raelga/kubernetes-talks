# Downward API Storage Examples

The Downward API allows pods to access information about themselves (name, namespace, IP, labels, annotations) through environment variables and volume mounts.

## Create the shell pod

```sh
kubectl apply -f 01-shell.yaml
```

## Review environment variables

```sh
kubectl exec -ti shell-api -- env | grep MY_POD
```

```
MY_POD_NAME=shell-api
MY_POD_NAMESPACE=default
MY_POD_IP=10.244.0.58
```

## Review mounted metadata

```sh
kubectl exec -ti shell-api -- cat /etc/api-info/labels
```

```
app="shell"
```

```sh
kubectl exec -ti shell-api -- cat /etc/api-info/annotations
```

```
build="v1.0.1"
builder="rael"
```

### Cleanup

```sh
kubectl delete -f 01-shell.yaml
```
