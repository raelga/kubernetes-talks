# Secrets

Secrets are similar to ConfigMaps but designed for sensitive data (passwords, tokens, keys). Key differences from ConfigMaps:

- Secret values are **base64-encoded** in the manifest (not encrypted — base64 is encoding, not encryption).
- Kubernetes can be configured to **encrypt Secrets at rest** in etcd.
- Secrets can be consumed as **environment variables** or **volume mounts**, just like ConfigMaps.
- When mounted as a volume, secret files are stored in a **tmpfs** (RAM-backed filesystem), so they are never written to disk on the node.

## Creating Secrets with kubectl

Create a secret from literal values:

```sh
kubectl create secret generic credentials \
    --from-literal=username=admin \
    --from-literal=password='secreto'
```

```
secret/credentials created
```

Create a secret from a file:

```sh
kubectl create secret generic readme \
    --from-file=README.md
```

```
secret/readme created
```

Inspect the secrets:

```sh
kubectl get secrets
```

```
NAME          TYPE     DATA   AGE
credentials   Opaque   2      10s
readme        Opaque   1      5s
```

The values are base64-encoded. You can decode them with:

```sh
kubectl get secret credentials -o jsonpath='{.data.username}' | base64 -d
```

```
admin
```

## Creating Secrets from a manifest

### Base64-encoded values (`data`)

The `01-secret.yaml` file defines a secret with **base64-encoded** values in the `data` field. This is the standard wire format Kubernetes uses internally:

```sh
kubectl apply -f 01-secret.yaml
```

```
secret/secret-config created
```

### Plaintext values (`stringData`)

`03-secret-string.yaml` uses `stringData` instead. Kubernetes accepts plaintext here and base64-encodes it automatically on the server side — useful when writing manifests by hand and you want to avoid running `echo -n "..." | base64`:

```sh
kubectl apply -f 03-secret-string.yaml
```

```
secret/secret-config-as-string created
```

Verify the value was stored and can be decoded:

```sh
kubectl get secret secret-config-as-string -o jsonpath='{.data.secret-key}' | base64 -d
```

```
Hola desde el Lab
```

> ⚠️ `stringData` is write-only — the API converts it to `data` (base64) on write and never returns `stringData` on reads. Running `kubectl get -o yaml` will show the value under `data`, not `stringData`.

Both `data` and `stringData` can coexist in the same manifest; `stringData` takes precedence for duplicate keys.

## Create a pod with Secrets attached

The pod mounts the secret as a read-only volume at `/etc/secret-volume/` and injects one key as an environment variable:

```sh
kubectl apply -f 02-shell.yaml
```

```
pod/shell-secret created
```

```sh
kubectl wait --for=condition=Ready pod/shell-secret --timeout=60s
```

## Review Secrets inside the pod

Check the environment variable:

```sh
kubectl exec shell-secret -- env | grep SECRET
```

```
SECRET_KEY=Hola desde el Lab
```

List the mounted secret files:

```sh
kubectl exec shell-secret -- ls /etc/secret-volume/
```

```
.secret-file
secret-key
```

Read the secret value:

```sh
kubectl exec shell-secret -- cat /etc/secret-volume/secret-key
```

```
Hola desde el Lab
```

The values are automatically decoded from base64 when mounted — containers see the original plaintext values.

### Cleanup

```sh
kubectl delete -f 02-shell.yaml
kubectl delete -f 01-secret.yaml
kubectl delete -f 03-secret-string.yaml
kubectl delete secret credentials readme
```
