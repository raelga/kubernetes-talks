# Shell Storage Examples

## Create the PVC

```
kubectl apply -f pvc.yaml
```

## Review PVC

```
kubectl get pvc volumen-pvc
```

## Create the shell pod

```
kubectl apply -f shell.yaml
```

## Attach to the pod and review the volumes

```
kubectl exec -ti shell-volumes -- /bin/bash
```

## Delete the shell pod

```
kubectl delete -f shell.yaml
```

## Review PVC

```
kubectl get pvc volumen-pvc
```

## Redeploy the shell pod

```
kubectl apply -f pod.yaml
```

## Attach to the pod and review the volumes

```
kubectl exec -ti shell-volumes -- /bin/bash
```
