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

## Guided 3-hour session

Use a local Kind cluster, not a cloud cluster. The linked exercises contain the manifests and detailed commands; run their commands from the exercise directory. Stop watches and port-forwards with `Ctrl+C`. The timings include discussion and cleanup.

| Time | Guided path and expected result |
|------|---------------------------------|
| 15 min | **Setup:** Follow [Kind basic cluster creation](../00-Kind/README.md#basic-cluster-creation), then `kubectl cluster-info --context kind-kind` and `kubectl get nodes`. Confirm the node is Ready and the active context is the intended local cluster (`kubectl config current-context`). Docker, Kind and kubectl should already be installed. |
| 25 min | **ReplicaSets:** In [create](../02-ReplicaSets/README.md#1---create-a-replicaset) and [scaling](../02-ReplicaSets/README.md#2---scaling-replicasets), apply `101_simple-rs.yaml`, inspect `kubectl get rs cats-gatet` and scale to 2 and back to 1. Delete one of its Pods and observe a replacement. Explain desired versus current replicas. Delete `rs/cats-gatet` before the probes exercise so selectors do not overlap. Skip the later scaling examples. |
| 25 min | **Probes:** Follow [readiness](../02-ReplicaSets/README.md#readiness-probe) through the working and failing examples, then [failing liveness](../02-ReplicaSets/README.md#liveness-probe-only-failing). Compare a Running but not Ready Pod with a restarting container; use `kubectl describe pod <pod-name>` for events. ReplicaSet template changes affect new Pods only. Finish with the [cleanup](../02-ReplicaSets/README.md#clean-up-1). |
| 10 min | **Break.** |
| 45 min | **Deployment:** Complete [cats](04.2-deployment/01-cats/README.md): apply the Deployment and Service, inspect Deployment → ReplicaSet → Pods, port-forward and access the app, roll out `lia.yaml`, inspect rollout history and undo. Expect the original image after rollback. Stop the port-forward and use the exercise cleanup. |
| 30 min | **Configuration:** Follow [ConfigMaps](../03-Storage/03.1-ConfigMaps/README.md) through creating the two ConfigMaps and Pod and inspecting the environment and mounted files. Then follow [Secrets from a manifest](../03-Storage/03.2-Secrets/README.md#creating-secrets-from-a-manifest) and the Pod inspection using both `01-secret.yaml` and `03-secret-string.yaml`. Compare configuration and sensitive data: base64 is not encryption; use only the synthetic lab values. Clean up the objects actually created in each exercise. |
| 15 min | **Jobs and CronJobs:** Guided demonstration of [Job with multiple completions](04.5-jobs/README.md#job-with-multiple-completions) and [CronJob](04.5-jobs/README.md#cronjob). Apply `job-5.yaml` and `cronjob.yaml`, inspect `kubectl get jobs` and `kubectl get cronjob hello`; observe a completed Pod and a scheduled Job if time permits. A Job finishes; a CronJob schedules Jobs. Delete the CronJob and Jobs as shown in the exercise. |
| 15 min | **Recap:** Explain reconciliation, readiness versus liveness, Deployment rollback, configuration versus secrets, and Job versus CronJob. Confirm the lab resources were cleaned up; delete the Kind cluster only if it is no longer needed. |

If setup or image pulls exceed the setup window, pair with a classmate or follow the instructor's local-cluster demonstration while inspecting the manifests and expected output; resume hands-on once available. If time is tight, demonstrate the Job/CronJob observations rather than waiting for every completion, preserving the recap and cleanup.

### Optional extensions

After the guided path, explore [selectors and Pod adoption](../02-ReplicaSets/README.md#3---selectors-and-pods), [manual rolling updates](../02-ReplicaSets/README.md#5---manual-rolling-update), [ConfigMap live updates](../03-Storage/03.1-ConfigMaps/README.md#update-the-configmap-live-reload), or the StatefulSet, DaemonSet, scheduling and release-strategy labs below. These are not required for the session.

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
