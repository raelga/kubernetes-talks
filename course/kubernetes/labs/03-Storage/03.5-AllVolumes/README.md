# All Volume Types

This lab mounts all six Kubernetes volume types into a single pod, so you can see each one side by side and understand when to use which.

| Mount path | Volume type | Backed by | Survives pod deletion? |
|------------|-------------|-----------|------------------------|
| `/etc/config` | ConfigMap | etcd | ✅ (ConfigMap object persists) |
| `/etc/secrets` | Secret | tmpfs (RAM) | ✅ (Secret object persists) |
| `/data` | PersistentVolumeClaim | Node disk / cloud storage | ✅ |
| `/scratch` | emptyDir `{}` | Node disk | ❌ |
| `/cache` | emptyDir `medium: Memory` | RAM (tmpfs) | ❌ |
| `/etc/podinfo` | DownwardAPI | Kubernetes metadata | N/A |

The pod also injects ConfigMap keys, Secret values, and pod metadata as **environment variables**.

## Deploy

Everything — the ConfigMap, Secret, PVC, and Pod — is defined in a single file:

```sh
kubectl apply -f all-volumes.yaml
kubectl wait --for=condition=Ready pod/all-volumes --timeout=60s
```

```
configmap/app-config created
secret/app-secrets created
persistentvolumeclaim/app-data created
pod/all-volumes created
pod/all-volumes condition met
```

## 1. ConfigMap → files

Keys become files under `/etc/config/`. The `config.properties` key is a multi-line file; `log_level` becomes a single-value file:

```sh
kubectl exec all-volumes -- ls /etc/config/
```

```
config.properties
log_level
```

```sh
kubectl exec all-volumes -- cat /etc/config/config.properties
```

```
version=1.0
feature.dark-mode=true
feature.analytics=false
```

## 2. ConfigMap → environment variable

`log_level` is also injected as `LOG_LEVEL` via `configMapKeyRef`:

```sh
kubectl exec all-volumes -- bash -c 'echo LOG_LEVEL=$LOG_LEVEL'
```

```
LOG_LEVEL=info
```

## 3. Secret → files

Secret values are decoded from base64 and written to a **tmpfs** (RAM-backed) mount at `/etc/secrets/` — they never touch the node's disk:

```sh
kubectl exec all-volumes -- ls /etc/secrets/
```

```
api-token
db-password
```

```sh
kubectl exec all-volumes -- cat /etc/secrets/db-password
```

```
s3cr3t!
```

```sh
kubectl exec all-volumes -- mount | grep '/etc/secrets'
```

```
tmpfs on /etc/secrets type tmpfs (ro,relatime,size=131072k,inode64,noswap)
```

## 4. Secret → environment variable

`db-password` is also injected as `DB_PASSWORD` via `secretKeyRef`:

```sh
kubectl exec all-volumes -- bash -c 'echo DB_PASSWORD=$DB_PASSWORD'
```

```
DB_PASSWORD=s3cr3t!
```

## 5. PersistentVolumeClaim → durable storage

`/data` is backed by a PVC — data written here survives pod deletion and rescheduling:

```sh
kubectl get pvc app-data
```

```
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
app-data   Bound    pvc-24668622-...                           1Gi        RWO            standard       10s
```

```sh
kubectl exec all-volumes -- bash -c 'echo "durable data" > /data/record.txt && cat /data/record.txt'
```

```
durable data
```

```sh
kubectl exec all-volumes -- mount | grep '/data '
```

```
/dev/vda4 on /data type xfs (rw,relatime,...)
```

## 6. emptyDir (disk) → ephemeral scratch

`/scratch` is a temporary directory on the node's disk. It is created when the pod starts and deleted when the pod is removed. Useful for build artifacts, temp files, or inter-container scratch space:

```sh
kubectl exec all-volumes -- bash -c 'echo "temp" > /scratch/temp.txt && cat /scratch/temp.txt'
```

```
temp
```

```sh
kubectl exec all-volumes -- mount | grep '/scratch'
```

```
/dev/vda4 on /scratch type xfs (rw,relatime,...)
```

## 7. emptyDir (Memory) → RAM-backed cache

`/cache` uses `medium: Memory` — it is backed by a tmpfs filesystem capped at 32 Mi. Reads and writes never touch disk, making it ideal for high-frequency scratch data or sensitive intermediate values:

```sh
kubectl exec all-volumes -- bash -c 'echo "fast" > /cache/item.txt && cat /cache/item.txt'
```

```
fast
```

```sh
kubectl exec all-volumes -- df -h /cache
```

```
Filesystem      Size  Used Avail Use% Mounted on
tmpfs            32M  4.0K   32M   1% /cache
```

## 8. DownwardAPI → pod metadata as files

Labels and annotations are exposed as files under `/etc/podinfo/` — they update automatically if labels/annotations change:

```sh
kubectl exec all-volumes -- ls /etc/podinfo/
```

```
annotations
labels
```

```sh
kubectl exec all-volumes -- cat /etc/podinfo/labels
```

```
app="all-volumes"
tier="demo"
```

```sh
kubectl exec all-volumes -- cat /etc/podinfo/annotations | grep -v 'last-applied'
```

```
team="platform"
version="1.0.0"
```

## 9. DownwardAPI → pod metadata as env vars

`POD_NAME` and `POD_NAMESPACE` are injected via `fieldRef` — set once at pod start, not updated dynamically:

```sh
kubectl exec all-volumes -- bash -c 'echo POD_NAME=$POD_NAME POD_NAMESPACE=$POD_NAMESPACE'
```

```
POD_NAME=all-volumes POD_NAMESPACE=default
```

## Volume type summary

```sh
kubectl exec all-volumes -- df -h | grep -E '/data|/cache|/etc/secrets|/etc/podinfo|Filesystem'
```

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda4        76G   26G   50G  35% /data        ← PVC (node disk)
tmpfs            32M     0   32M   0% /cache        ← emptyDir Memory
tmpfs           128M  8.0K  128M   1% /etc/secrets  ← Secret (RAM)
tmpfs           128M  8.0K  128M   1% /etc/podinfo  ← DownwardAPI (RAM)
```

> `/etc/config` and `/scratch` share the node's root filesystem and don't show as separate entries in `df`.

### Cleanup

```sh
kubectl delete -f all-volumes.yaml
```

> ⚠️ The PVC is **not** deleted by deleting the pod. The `kubectl delete -f all-volumes.yaml` command deletes the PVC object too (it is declared in the same file), which also releases the underlying PersistentVolume.
