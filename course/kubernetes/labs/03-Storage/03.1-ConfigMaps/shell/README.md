# Shell Storage Examples

## Create the game config configmap

```
kubectl apply -f game-config-configmap.yaml
```

## Create the game env configmap

```
kubectl apply -f game-env-configmap.yaml
```

## Create the shell pod with the configmaps attached

```
kubectl apply -f pod.yaml
```

## Attach to the pod and review the configmaps

```
kubectl exec -ti shell -- /bin/bash
```

## Update the game config configmap

```
kubectl apply -f game-config-configmap-v2.yaml
```
