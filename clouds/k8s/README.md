# Kubernetes applications

Follow the [execution guide](../RUNBOOK.md) for preparation, rollout checks and Cloudflare routing. Run these commands from the project root.

Both variants use the same UI and image, pinned in `base/kustomization.yaml`, and the same `guestbook` Deployment and LoadBalancer Service with `app=guestbook` selectors.

```text
base/               # Deployment, Service and image pin
local/              # Redis configuration
shared/             # Worker/D1 configuration
  credentials.env   # private, ignored application token
overlays/           # provider location and replica settings
```

All demo infrastructure is currently destroyed; preserve historical state/backups and private inputs. Fresh approved clusters deploy the stable `guestbook` resources directly and have no legacy migration gate. The [legacy cleanup reference](../RUNBOOK-DETAILED.md#legacy-names-from-the-running-installation) documents former app names only; no live deployment or deletion is authorized here.

## Local datastore

```bash
kubectl --context eks apply -k k8s/overlays/aws/local
kubectl --context aks apply -k k8s/overlays/azure/local
kubectl --context gke apply -k k8s/overlays/gcp/local
kubectl --context doks apply -k k8s/overlays/digitalocean/local
```

Wait for `guestbook-local-redis` and `guestbook` to be ready. Configure Cloudflare once with the `guestbook` Service addresses using the execution guide.

## Shared datastore

Reuse the retained private `k8s/shared/credentials.env` application token when recreating Worker/D1; see [token setup](../RUNBOOK-DETAILED.md#existing-application-token-reuse-never-regenerate). Do not print rendered Shared datastore YAML: it contains credentials.

```bash
kubectl --context eks apply -k k8s/overlays/aws/shared
kubectl --context aks apply -k k8s/overlays/azure/shared
kubectl --context gke apply -k k8s/overlays/gcp/shared
kubectl --context doks apply -k k8s/overlays/digitalocean/shared
```

This rolls the same `guestbook` Deployment; the Service and Cloudflare origins stay unchanged. Old Local and new Shared Pods can coexist briefly during rollout. Wait for rollout completion and all desired replicas Ready before demonstrating Shared datastore, as shown in the execution guide. Switching variants does not migrate messages; retain local Redis for a later switch back.

For teardown, follow the [approved cleanup procedure](../RUNBOOK-DETAILED.md#cleanup).
