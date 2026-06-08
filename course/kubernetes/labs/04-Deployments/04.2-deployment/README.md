# Deployment

A **Deployment** provides declarative updates for Pods and ReplicaSets: rolling updates, rollback, and revision history. This section builds up from a minimal example to full application stacks.

| Example | Description |
|---------|-------------|
| [01-cats](01-cats/) | Core Deployment workflow: rollout, rolling update, history, and rollback. **Start here.** |
| [05-kustomize-rollout](05-kustomize-rollout/) | `configMapGenerator` & `secretGenerator`: every config change automatically triggers a rollout. |
| [02-kubernetes-dashboard](02-kubernetes-dashboard/) | Deploy the Kubernetes Dashboard and wire up RBAC access. |
| [03-guestbook](03-guestbook/) | Classic multi-tier app (frontend + Redis master/replica). |
| [04-wordpress](04-wordpress/) | WordPress + MySQL with a PersistentVolumeClaim. |

> The `01-cats` example is the canonical Deployment walkthrough and is verified against a [Kind](../../00-Kind/README.md) cluster. The others are larger end-to-end stacks.
