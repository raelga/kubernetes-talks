# Volume Storage Examples

This section provides examples of how to use Persistent Volume Claims (PVCs)
in Kubernetes.

## Create the PVC

This command applies the configuration from the `pvc.yaml` file to create
the Persistent Volume Claim.

```sh
kubectl apply -f pvc.yaml
```

## Review PVC

This command retrieves the details of the Persistent Volume Claim
named `volumen-pvc`.

```sh
kubectl get pvc volumen-pvc
```

## Create the shell pod

This command applies the configuration from the `shell.yaml` file
to create a pod.

```sh
kubectl apply -f shell.yaml
```

## Attach to the pod and review the volumes

This command allows you to execute a bash shell inside the `shell-volumes` pod.
Once inside, you can review the volumes.

```sh
kubectl exec -ti shell-volumes -- /bin/bash
```

## Delete the shell pod

This command deletes the pod created from the `shell.yaml` file.

```sh
kubectl delete -f shell.yaml
```

## Review PVC

This command retrieves the details of the Persistent Volume Claim named
`volumen-pvc` again, to verify that it still exists after the pod deletion.

```sh
kubectl get pvc volumen-pvc
```

## Redeploy the shell pod

This command redeploys the pod using the configuration from the `pod.yaml` file.
The pod is created with the same Persistent Volume Claim attached, allowing it
to access the same data as before.

```sh
kubectl apply -f pod.yaml
```

## Attach to the pod and review the volumes

This command allows you to execute a bash shell inside the `shell-volumes` pod.
Once inside, you can review the volumes to verify that the data from the
Persistent Volume Claim is still accessible.

```sh
kubectl exec -ti shell-volumes -- /bin/bash
```
