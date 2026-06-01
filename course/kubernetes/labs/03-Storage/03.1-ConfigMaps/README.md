# ConfigMap Storage Examples

This section provides examples of how to use ConfigMap storage in Kubernetes.

## Create the game config configmap

```sh
kubectl apply -f 01-game-config-configmap.yaml
```

## Create the game env configmap

```sh
kubectl apply -f 02-game-env-configmap.yaml
```

## Create the shell pod with the configmaps attached

```sh
kubectl apply -f 03-pod.yaml
```

## Attach to the pod and review the configmaps

```sh
kubectl exec -ti shell -- /bin/bash
```

Inside the pod, check the environment variables and mounted volume:

```sh
echo $ENVIRONMENT
echo $DEBUG
cat /etc/game-config/game.properties
```

## Update the game config configmap

```sh
kubectl apply -f 04-game-config-configmap-v2.yaml
```

Wait a few seconds for the volume to update, then check again inside the pod:

```sh
kubectl exec -ti shell -- cat /etc/game-config/game.properties
```

### Cleanup

```sh
kubectl delete -f 03-pod.yaml
kubectl delete -f 01-game-config-configmap.yaml
kubectl delete -f 02-game-env-configmap.yaml
```
