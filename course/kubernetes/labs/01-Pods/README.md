# Pods

A Pod is the smallest deployable unit in Kubernetes. It represents a single instance of a running process and can contain one or more containers that share networking and storage.

## Prerequisites

- A running Kubernetes cluster (e.g., [Kind](../00-Kind/README.md))
- `kubectl` configured to communicate with the cluster
- Run each lab's commands from its own directory, in a disposable namespace or cluster. The examples use the current namespace and some create many pods.
- Wait for pods and images to start before `exec` or `logs`; use `kubectl describe pod <name>` to investigate delays. Stop `-w` and `logs -f` commands with Ctrl-C.

## Labs

| Lab | Topic | Description |
|-----|-------|-------------|
| [01.1-Basics](01.1-Basics/) | Pod fundamentals | Create, inspect, and delete pods. Labels, selectors, and basic kubectl commands. |
| [01.2-Resources](01.2-Resources/) | CPU & Memory | Requests, limits, QoS classes (Guaranteed, Burstable, BestEffort), and scheduling behavior. |
| [01.3-Multi](01.3-Multi/) | Multi-container pods | Network sharing, volume sharing, and the sidecar pattern. |
| [01.4-lifecycle](01.4-lifecycle/) | Health probes | Readiness and liveness probes using exec and TCP checks. |
| [01.5-init-containers](01.5-init-containers/) | Init containers | Sequential initialization, dependency waiting, and pod startup ordering. |

## Local kind run

On 2026-11-26 these manifests were exercised on kind running Kubernetes v1.35.0 with one
control-plane and two worker nodes. The 31-pod basics batch became ready on
both workers; applying the 100-pod manifest created 101 pods including the
single pod. The CUDA selector remained Pending without a matching GPU node,
while the preferred-affinity pod ran. Guaranteed and Burstable QoS classes,
shared networking and volumes, and the init-container DNS dependency were
observed. The 4-CPU request scheduled on this cluster; it is not inherently
unschedulable. GPU execution requires suitable hardware and was not tested.
A temporary 100000-CPU request produced `FailedScheduling` for insufficient
CPU. Exec readiness failures left containers running, and liveness failures
restarted them; the TCP probe pod became ready. Sidecar content was also
served through port-forwarding.

The optional `kubectl top` worked after installing metrics-server and
configuring it to use insecure kubelet TLS for this isolated kind cluster;
metrics-server is not included by default.
