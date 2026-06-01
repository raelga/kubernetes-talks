# Downward API

The Downward API allows containers to access information about themselves and the pod they're running in, **without calling the Kubernetes API**. This is useful for:

- Passing the pod name or namespace to an application for logging
- Getting the pod IP for service discovery
- Reading labels and annotations set at deploy time

Data can be exposed in two ways:

- **Environment variables**: Using `fieldRef` to inject metadata fields like `metadata.name`, `metadata.namespace`, or `status.podIP`.
- **Volume mounts**: Using a `downwardAPI` volume to expose labels and annotations as files.

## Create the pod

The `01-shell.yaml` pod exposes metadata through both mechanisms:

```sh
kubectl apply -f 01-shell.yaml
```

```
pod/shell-api created
```

```sh
kubectl wait --for=condition=Ready pod/shell-api --timeout=60s
```

## Review environment variables

The pod injects `metadata.name`, `metadata.namespace`, and `status.podIP` as environment variables:

```sh
kubectl exec shell-api -- env | grep MY_POD
```

```
MY_POD_NAME=shell-api
MY_POD_NAMESPACE=default
MY_POD_IP=10.244.0.58
```

These values are set at pod startup and **do not update** if the pod metadata changes.

## Review mounted metadata

Labels and annotations are mounted as files at `/etc/api-info/`:

```sh
kubectl exec shell-api -- ls /etc/api-info/
```

```
annotations
labels
```

```sh
kubectl exec shell-api -- cat /etc/api-info/labels
```

```
app="shell"
```

```sh
kubectl exec shell-api -- cat /etc/api-info/annotations
```

```
build="v1.0.1"
builder="rael"
```

Unlike environment variables, volume-mounted metadata **updates automatically** when labels or annotations change. Kubernetes also adds its own internal annotations (like `kubectl.kubernetes.io/last-applied-configuration`), which will appear in the annotations file.

### Cleanup

```sh
kubectl delete -f 01-shell.yaml
```
