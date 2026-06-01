# Volume Storage Examples

This section provides examples of how to use Persistent Volume Claims (PVCs) in Kubernetes.

## Create the PVC

```sh
kubectl apply -f 01-pvc.yaml
```

## Review PVC

```sh
kubectl get pvc volumen-pvc
```

## Create the shell pod

```sh
kubectl apply -f 02-shell.yaml
```

## Attach to the pod and write some data

```sh
kubectl exec -ti shell-volumes -- /bin/bash
```

Inside the pod, write data to the persistent volume:

```sh
echo "Hello from the first pod!" > /data/test.txt
cat /data/test.txt
exit
```

## Delete the shell pod

```sh
kubectl delete -f 02-shell.yaml
```

## Review PVC

Verify that the PVC still exists after the pod deletion:

```sh
kubectl get pvc volumen-pvc
```

## Redeploy the shell pod

Recreate the pod with the same PVC attached:

```sh
kubectl apply -f 02-shell.yaml
```

## Verify data persistence

```sh
kubectl exec -ti shell-volumes -- cat /data/test.txt
```

The data written by the first pod is still available because the PVC persists independently of the pod lifecycle.

### Cleanup

```sh
kubectl delete -f 02-shell.yaml
kubectl delete -f 01-pvc.yaml
```
