# Kustomize: Config Changes That Trigger Rollouts

## The problem with plain ConfigMaps

In the [previous lab](../01-cats/) you saw that updating a ConfigMap **does not restart pods**. Pods that consume ConfigMaps via environment variables (`envFrom`) keep the old values until they are manually restarted. This is a common source of configuration drift in production.

## The Kustomize solution: content-hashed names

Kustomize's `configMapGenerator` and `secretGenerator` address this by **appending a hash of the content to the resource name** at build time:

```
app-config        →  app-config-4k46b8b7gc
app-secrets       →  app-secrets-mtdd5khm58
```

Because the Deployment's pod template references the hashed name, **any change to the content produces a new hash**, which changes the pod template, which triggers a rolling update — automatically, with no manual restart required.

## Lab files

```
.
├── kustomization.yaml   # generators + resources
├── deployment.yaml      # references app-config and app-secrets by base name
├── app.env              # non-sensitive config key=value pairs
└── secrets.env          # sensitive values (gitignored)
```

`secrets.env` is listed in `.gitignore` — in a real project you would populate it from a secrets manager (Vault, AWS Secrets Manager, etc.) at deploy time.

## Preview the generated output

Before applying anything, inspect what Kustomize produces:

```sh
kubectl kustomize .
```

Notice that the ConfigMap and Secret names already carry the content hash, and the Deployment's `envFrom` references those hashed names — Kustomize wires this up automatically:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-4k46b8b7gc    # ← hash of app.env content
...
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets-mtdd5khm58   # ← hash of secrets.env content
...
---
apiVersion: apps/v1
kind: Deployment
...
        envFrom:
        - configMapRef:
            name: app-config-4k46b8b7gc    # ← injected by Kustomize
        - secretRef:
            name: app-secrets-mtdd5khm58   # ← injected by Kustomize
```

## Apply the initial configuration

`kubectl apply -k .` builds with Kustomize and applies in one step:

```sh
kubectl apply -k .
```

```
configmap/app-config-4k46b8b7gc created
secret/app-secrets-mtdd5khm58 created
deployment.apps/hello created
```

```sh
kubectl rollout status deployment/hello
```

```
deployment "hello" successfully rolled out
```

Verify the config values inside a pod:

```sh
kubectl exec deploy/hello -- bash -c 'env | grep -E "APP_ENV|LOG_LEVEL|DB_HOST|API_KEY"'
```

```
APP_ENV=production
LOG_LEVEL=info
DB_HOST=mysql.default.svc.cluster.local
API_KEY=abc123
```

## Update the ConfigMap — rollout triggers automatically

Change `LOG_LEVEL` from `info` to `debug` in `app.env`:

```sh
sed -i 's/LOG_LEVEL=info/LOG_LEVEL=debug/' app.env
```

Preview the new hash — it changed because the content changed:

```sh
kubectl kustomize . | grep 'name: app-config'
```

```
  name: app-config-m7d76d6f84    # ← new hash
```

Apply and watch the rollout happen automatically:

```sh
kubectl apply -k .
kubectl rollout status deployment/hello
```

```
configmap/app-config-m7d76d6f84 created
secret/app-secrets-mtdd5khm58 unchanged
deployment.apps/hello configured
Waiting for deployment "hello" rollout to finish: 1 out of 3 new replicas have been updated...
deployment "hello" successfully rolled out
```

The Secret was unchanged (its hash didn't change), so no new Secret was created and no extra rollout was triggered. The new pods pick up the updated config without any manual restart:

```sh
kubectl exec deploy/hello -- bash -c 'env | grep LOG_LEVEL'
```

```
LOG_LEVEL=debug
```

## Rotate a Secret — rollout triggers automatically too

Change `API_KEY` in `secrets.env`:

```sh
sed -i 's/API_KEY=abc123/API_KEY=xyz789/' secrets.env
```

```sh
kubectl apply -k .
kubectl rollout status deployment/hello
```

```
configmap/app-config-m7d76d6f84 unchanged
secret/app-secrets-8c7kft877f created    # ← new hash, new secret
deployment.apps/hello configured
deployment "hello" successfully rolled out
```

```sh
kubectl exec deploy/hello -- bash -c 'env | grep API_KEY'
```

```
API_KEY=xyz789
```

The old secret (`app-secrets-mtdd5khm58`) is kept around until garbage-collected, so a rollback can still reference it.

## Rollback

Because every config change creates a new Deployment revision, `rollout undo` works as expected. It restores the pod template to the previous revision's hashed names, which still exist in the cluster:

```sh
kubectl rollout history deployment/hello
```

```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
3         <none>
```

```sh
kubectl rollout undo deployment/hello
kubectl rollout status deployment/hello
```

```
deployment.apps/hello rolled back
deployment "hello" successfully rolled out
```

```sh
kubectl exec deploy/hello -- bash -c 'env | grep -E "LOG_LEVEL|API_KEY"'
```

```
LOG_LEVEL=debug
API_KEY=abc123
```

> ⚠️ **Rollback restores the pod template** (which ConfigMap/Secret names are referenced), but it does **not** modify the Secret or ConfigMap data objects themselves. If you need to roll back the secret *contents*, update `secrets.env` and re-apply.

## Why this matters

| | Plain `kubectl apply` on a ConfigMap | Kustomize generators |
|---|---|---|
| Config change triggers rollout | ❌ No | ✅ Yes (hash change → new name → new pod template) |
| Env vars pick up new values | ❌ Not until pod restart | ✅ New pods start with latest values |
| Rollback includes config state | ❌ No — config drifts | ✅ Each revision pins specific hashed names |
| Old versions kept for rollback | ❌ Overwritten in place | ✅ Old ConfigMaps/Secrets remain until GC'd |

### Cleanup

```sh
kubectl delete -k .
```
