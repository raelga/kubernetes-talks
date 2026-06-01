# Persistent Volumes

Pods are ephemeral — when a pod is deleted, its filesystem is lost. To persist data across pod restarts, Kubernetes provides **Persistent Volumes (PV)** and **Persistent Volume Claims (PVC)**.

- **PersistentVolume (PV)**: A piece of storage provisioned by an administrator or dynamically by a StorageClass.
- **PersistentVolumeClaim (PVC)**: A request for storage by a pod. The PVC binds to an available PV.
- **StorageClass**: Defines how to dynamically provision PVs (e.g., SSD, HDD, network storage).

The key concept: **PVCs outlive pods**. Deleting a pod does not delete the PVC or its data.

This lab also uses an **emptyDir** volume, which is a temporary directory that exists for the lifetime of the pod (shared between containers, but lost when the pod is deleted).

## Create the PVC

```sh
kubectl apply -f 01-pvc.yaml
```

```
persistentvolumeclaim/volumen-pvc created
```

Check the PVC status:

```sh
kubectl get pvc volumen-pvc
```

```
NAME          STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
volumen-pvc   Pending                                      standard       5s
```

The PVC is `Pending` because no pod is using it yet. Kind uses a `standard` StorageClass that provisions volumes on demand when a pod mounts the PVC.

## Create the pod

The pod mounts two volumes:
- `/data` — backed by the PVC (persistent)
- `/tmp-data` — backed by emptyDir (ephemeral)

```sh
kubectl apply -f 02-shell.yaml
```

```
pod/shell-volumes created
```

```sh
kubectl wait --for=condition=Ready pod/shell-volumes --timeout=60s
```

Check the PVC again — it should now be `Bound`:

```sh
kubectl get pvc volumen-pvc
```

```
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
volumen-pvc   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   3Gi        RWO            standard       30s
```

## Write data to the persistent volume

```sh
kubectl exec shell-volumes -- sh -c 'echo "Hello from the first pod!" > /data/test.txt'
kubectl exec shell-volumes -- cat /data/test.txt
```

```
Hello from the first pod!
```

Also write data to the emptyDir volume for comparison:

```sh
kubectl exec shell-volumes -- sh -c 'echo "This will be lost" > /tmp-data/ephemeral.txt'
```

## Delete the pod

```sh
kubectl delete -f 02-shell.yaml
```

```
pod "shell-volumes" deleted
```

Check that the PVC still exists:

```sh
kubectl get pvc volumen-pvc
```

```
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
volumen-pvc   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   3Gi        RWO            standard       60s
```

The PVC is still `Bound` — the data persists even though the pod is gone.

## Recreate the pod and verify data persistence

```sh
kubectl apply -f 02-shell.yaml
kubectl wait --for=condition=Ready pod/shell-volumes --timeout=60s
```

Check the persistent volume — data is still there:

```sh
kubectl exec shell-volumes -- cat /data/test.txt
```

```
Hello from the first pod!
```

Check the emptyDir — data is gone (new pod, new emptyDir):

```sh
kubectl exec shell-volumes -- cat /tmp-data/ephemeral.txt
```

```
cat: can't open '/tmp-data/ephemeral.txt': No such file or directory
```

This demonstrates the key difference: **PVC data survives pod deletion**, while **emptyDir data does not**.

### Cleanup

```sh
kubectl delete -f 02-shell.yaml
kubectl delete -f 01-pvc.yaml
```
