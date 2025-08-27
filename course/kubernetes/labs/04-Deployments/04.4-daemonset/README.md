# DaemonSet Lab - Hostname Service

## Overview

This lab demonstrates Kubernetes DaemonSets, which ensure that a copy of a pod runs on every node in the cluster. DaemonSets are commonly used for system daemons, monitoring agents, log collectors, and other node-level services.

## Prerequisites

- A running Kubernetes cluster with multiple nodes
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes pods and deployments

## Lab Objectives

- Deploy a DaemonSet that runs on every cluster node
- Understand DaemonSet behavior and scheduling
- Perform rolling updates on DaemonSets
- Explore the Downward API for accessing pod/node information
- Compare DaemonSets with other workload types

## Instructions

### 1. Deploy the initial DaemonSet

```bash
kubectl apply -f hostname-ds.yaml
```

### 2. Verify DaemonSet deployment

Check that pods are running on all nodes:

```bash
kubectl get pods -l app=hostname
kubectl get nodes
```

**Expected Result**: The number of pods should equal the number of nodes in your cluster.

### 3. Monitor DaemonSet logs

```bash
kubectl logs -f -l app=hostname
```

### 4. Perform a rolling update with Downward API

Deploy version 2 which includes Downward API volume mounts:

```bash
kubectl apply -f hostname-v2-ds.yaml
```

### 5. Watch the rolling update

```bash
kubectl get pods -l app=hostname -w
```

### 6. Explore the Downward API

Connect to one of the updated pods and examine the Downward API information:

```bash
kubectl exec -ti $(kubectl get pods -l app=hostname -o name --field-selector=status.phase==Running | head -n1) -- /bin/bash
```

Inside the pod, check the `/etc/podinfo` folder to see the information provided by the Downward API.

### 7. Examine pod distribution

Verify pods are distributed across all nodes:

```bash
kubectl get pods -l app=hostname -o wide
```

## Cleanup

Remove all resources created in this lab:

```bash
kubectl delete all -l app=hostname
```

## Key Concepts

- **DaemonSet**: Ensures one pod copy runs on every node
- **Node Selection**: DaemonSets automatically schedule on all nodes (unless restricted)
- **Rolling Updates**: DaemonSets support rolling update strategies
- **Downward API**: Provides pod and node metadata to containers
- **System Services**: Common use case for cluster-wide services

## DaemonSet Use Cases

- **Log Collection**: Fluentd, Filebeat for centralized logging
- **Monitoring**: Node monitoring agents like Node Exporter
- **Storage**: Distributed storage daemons like Ceph
- **Networking**: CNI plugins and network monitoring tools
- **Security**: Security scanning and compliance agents

## Comparison with Other Workloads

| Feature | DaemonSet | Deployment | StatefulSet |
|---------|-----------|------------|-------------|
| Scheduling | One per node | Distributed | Ordered |
| Scaling | Auto (with nodes) | Manual/Auto | Manual |
| Use Case | System services | Stateless apps | Stateful apps |

## Troubleshooting

- If pods don't appear on all nodes, check node taints and tolerations
- DaemonSets ignore resource requests/limits for scheduling decisions
- Use `kubectl describe daemonset` to check for issues
- Downward API data is mounted as files in the specified volume path
