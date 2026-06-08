# Deployments & Workloads

Pods and ReplicaSets are the building blocks, but you rarely create them directly. Kubernetes provides higher-level **workload controllers** that manage Pods for you — handling rollouts, scaling, scheduling, and batch execution.

## Prerequisites

- A running Kubernetes cluster (e.g., [Kind](../00-Kind/README.md))
- `kubectl` configured to communicate with the cluster
- Some labs (DaemonSet, affinity/anti-affinity) are more illustrative on a **multi-node** cluster:

  ```sh
  cat <<EOF | kind create cluster --config=-
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
  - role: control-plane
  - role: worker
  - role: worker
  EOF
  ```

## Labs

| Lab | Topic | Description |
|-----|-------|-------------|
| [04.1-replicaset](04.1-replicaset/) | ReplicaSet | Keep a fixed number of Pod replicas running. Labels, selectors, and selector overlap. |
| [04.2-deployment](04.2-deployment/) | Deployment | Declarative rollouts on top of ReplicaSets: rolling updates, history, and rollback. |
| [04.3-statefulset](04.3-statefulset/) | StatefulSet | Stable network identity and per-Pod persistent storage for stateful apps (MySQL). |
| [04.4-daemonset](04.4-daemonset/) | DaemonSet | Run exactly one Pod copy on every node. Node-level agents and the Downward API. |
| [04.5-jobs](04.5-jobs/) | Jobs & CronJobs | Run Pods to completion and on a schedule. `completions`, `generateName`, cron syntax. |
| [04.6-affinity-and-antiaffinity](04.6-affinity-and-antiaffinity/) | Scheduling | Control where Pods land: node selectors, pod affinity/anti-affinity, taints & tolerations. |
| [04.8-application-bundles](04.8-application-bundles/) | Packaging | Bundle apps with Helm, Operators, and Kustomize. *(Requires extra tooling.)* |
| [04.9-deployment-strategies](04.9-deployment-strategies/) | Release strategies | Recreate, ramped, blue-green, canary, A/B testing, and shadow. *(Some require Istio/NGINX.)* |

## Workload controller cheat sheet

| Controller | Guarantees | Typical use case |
|------------|-----------|------------------|
| **ReplicaSet** | N identical replicas | Building block (managed by Deployments) |
| **Deployment** | N replicas + rollouts/rollback | Stateless apps |
| **StatefulSet** | Stable identity + ordered + per-Pod storage | Databases, clustered apps |
| **DaemonSet** | One Pod per node | Log/metric agents, CNI, storage daemons |
| **Job** | Run to completion | Batch tasks |
| **CronJob** | Scheduled Jobs | Recurring tasks |
