# Configmap Storage Examples

This section provides examples of how to use ConfigMap storage in Kubernetes.

## Create the game config configmap

This command applies the configuration from the `game-config-configmap.yaml`
file to create the game config ConfigMap.

```sh
kubectl apply -f game-config-configmap.yaml
```

## Create the game env configmap

This command applies the configuration from the `game-env-configmap.yaml`
file to create the game environment ConfigMap.

```sh
kubectl apply -f game-env-configmap.yaml
```

## Create the shell pod with the configmaps attached

This command applies the configuration from the `pod.yaml`
file to create a pod with attached ConfigMaps.

```sh
kubectl apply -f pod.yaml
```

## Attach to the pod and review the configmaps

This command allows you to execute a bash shell inside the `shell` pod.
Once inside, you can review the ConfigMaps.

```sh
kubectl exec -ti shell -- /bin/bash
```

## Update the game config configmap

This command applies the updated configuration from the
`game-config-configmap-v2.yaml` file to update the game config ConfigMap.

```sh
kubectl apply -f game-config-configmap-v2.yaml
```
