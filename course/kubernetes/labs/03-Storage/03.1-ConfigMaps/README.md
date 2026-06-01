# ConfigMaps

A ConfigMap is a Kubernetes object that stores non-confidential configuration data as key-value pairs. Pods can consume ConfigMaps in two ways:

- **Environment variables**: Individual keys are injected as env vars into the container.
- **Volume mounts**: The entire ConfigMap is mounted as a directory, where each key becomes a file.

Volume-mounted ConfigMaps are **automatically updated** when the ConfigMap changes (with a small delay), while environment variables require a pod restart.

## Create the ConfigMaps

The `01-game-config-configmap.yaml` creates a ConfigMap with two configuration files (`game.properties` and `ui.properties`):

```sh
kubectl apply -f 01-game-config-configmap.yaml
```

```
configmap/game-config created
```

The `02-game-env-configmap.yaml` creates a ConfigMap with simple key-value pairs for use as environment variables:

```sh
kubectl apply -f 02-game-env-configmap.yaml
```

```
configmap/game-env created
```

Inspect the ConfigMaps:

```sh
kubectl get configmaps
```

```
NAME               DATA   AGE
game-config        2      10s
game-env           2      5s
```

## Create the pod with ConfigMaps attached

The pod manifest (`03-pod.yaml`) references both ConfigMaps:
- `game-env` keys are injected as environment variables (`ENVIRONMENT`, `DEBUG`)
- `game-config` is mounted as a volume at `/etc/game-config/`

```sh
kubectl apply -f 03-pod.yaml
```

```
pod/shell created
```

```sh
kubectl wait --for=condition=Ready pod/shell --timeout=60s
```

## Review the ConfigMap data inside the pod

Check the environment variables injected from `game-env`:

```sh
kubectl exec shell -- env | grep -E "ENVIRONMENT|DEBUG|EXTRA"
```

```
ENVIRONMENT=testing
DEBUG=10
EXTRA=lab
```

Check the files mounted from `game-config`:

```sh
kubectl exec shell -- ls /etc/game-config/
```

```
game.properties
ui.properties
```

```sh
kubectl exec shell -- cat /etc/game-config/game.properties
```

```
version=v1
enemies=aliens
lives=3
enemies.cheat=true
enemies.cheat.level=noGoodRotten
secret.code.passphrase=UUDDLRLRBABAS
secret.code.allowed=true
secret.code.lives=30
```

## Update the ConfigMap (live reload)

Apply the updated ConfigMap with `version=v2`:

```sh
kubectl apply -f 04-game-config-configmap-v2.yaml
```

```
configmap/game-config configured
```

Wait a few seconds for the volume to update (Kubernetes syncs mounted ConfigMaps periodically), then verify the change:

```sh
kubectl exec shell -- cat /etc/game-config/game.properties | grep version
```

```
version=v2
```

The pod picked up the new configuration **without a restart**. This only works for volume-mounted ConfigMaps — environment variables would still show the old value until the pod is recreated.

### Cleanup

```sh
kubectl delete -f 03-pod.yaml
kubectl delete -f 01-game-config-configmap.yaml
kubectl delete -f 02-game-env-configmap.yaml
```
