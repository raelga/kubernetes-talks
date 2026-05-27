# Pods

A Pod is the smallest deployable unit in Kubernetes. It represents a single instance of a running process and can contain one or more containers that share networking and storage.

## Prerequisites

- A running Kubernetes cluster (e.g., [Kind](../00-Kind/README.md))
- `kubectl` configured to communicate with the cluster

## Labs

| Lab | Topic | Description |
|-----|-------|-------------|
| [01.1-Basics](01.1-Basics/) | Pod fundamentals | Create, inspect, and delete pods. Labels, selectors, and basic kubectl commands. |
| [01.2-Resources](01.2-Resources/) | CPU & Memory | Requests, limits, QoS classes (Guaranteed, Burstable, BestEffort), and scheduling behavior. |
| [01.3-Multi](01.3-Multi/) | Multi-container pods | Network sharing, volume sharing, and the sidecar pattern. |
| [01.4-lifecycle](01.4-lifecycle/) | Health probes | Readiness and liveness probes using exec, HTTP, and TCP checks. |
| [01.5-init-containers](01.5-init-containers/) | Init containers | Sequential initialization, dependency waiting, and pod startup ordering. |
