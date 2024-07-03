# Secret Storage Examples

This section provides examples of how to use secret storage in Kubernetes.

## Creating secrets using kubectl

This command creates a secret named `credentials` with two key-value pairs:

- `username=admin`
- `password=secreto`

```
kubectl create secret generic credentials \
    --from-literal=username=admin \
    --from-literal=password='secreto'
```

This command creates a secret named `readme` from the `README.md` file.

```
kubectl create secret generic readme \
    --from-file=README.md
```

## Create the secret config

This command applies the configuration from the `secret.yaml` file
to create the secret in Kubernetes.

```
kubectl apply -f secret.yaml
```

## Create the shell pod with the secrets attached

This command applies the configuration from the `shell.yaml` file
to create a pod with attached secrets.

```
kubectl apply -f shell.yaml
```

## Attach to the pod and review the secrets

This command allows you to execute a bash shell inside the `shell-secret` pod.
Once inside, you can review the secrets.

```
kubectl exec -ti shell-secret -- /bin/bash
```
