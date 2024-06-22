# Shell Storage Examples

## Creating secrets using kubectl

```
kubectl create secret generic credentials \
    --from-literal=username=admin \
    --from-literal=password='secreto'
```

```
kubectl create secret generic readme \
    --from-file=README.md
```

## Create the secret config

```
kubectl apply -f secret.yaml
```

## Create the shell pod with the configmaps attached

```
kubectl apply -f shell.yaml
```

## Attach to the pod and review the configmaps

```
kubectl exec -ti shell-secret -- /bin/bash
```
