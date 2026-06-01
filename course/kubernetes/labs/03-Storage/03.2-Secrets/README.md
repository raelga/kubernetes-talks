# Secret Storage Examples

This section provides examples of how to use secret storage in Kubernetes.

## Creating secrets using kubectl

Create a secret named `credentials` with two key-value pairs:

```sh
kubectl create secret generic credentials \
    --from-literal=username=admin \
    --from-literal=password='secreto'
```

Create a secret named `readme` from the `README.md` file:

```sh
kubectl create secret generic readme \
    --from-file=README.md
```

## Create the secret from a manifest

```sh
kubectl apply -f 01-secret.yaml
```

## Create the shell pod with the secrets attached

```sh
kubectl apply -f 02-shell.yaml
```

## Attach to the pod and review the secrets

```sh
kubectl exec -ti shell-secret -- /bin/bash
```

Inside the pod, check the mounted secrets and environment variables:

```sh
echo $SECRET_KEY
ls /etc/secret-volume/
cat /etc/secret-volume/secret-key
```

### Cleanup

```sh
kubectl delete -f 02-shell.yaml
kubectl delete -f 01-secret.yaml
kubectl delete secret credentials readme
```
