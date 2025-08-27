# Pod Affinity, Anti-Affinity, and Taints/Tolerations Lab

## Overview

This lab explores advanced Kubernetes scheduling concepts including node selectors, pod affinity/anti-affinity, and taints/tolerations. These features give you fine-grained control over where pods are scheduled in your cluster.

## Prerequisites

- A running Kubernetes cluster with multiple nodes
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes pods and deployments

## Lab Objectives

- Understand node selection mechanisms
- Implement pod affinity and anti-affinity rules
- Work with taints and tolerations
- Observe pod scheduling behavior
- Compare different scheduling strategies

## Part 1: Node Selector

### 1. Deploy with node selector

```bash
kubectl apply -f hostname-node-selector-deployment.yaml
```

### 2. Monitor pod placement

Keep this shell visible to watch pod scheduling:

```bash
watch kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name
```

### 3. Get available nodes

```bash
kubectl get nodes -o name
```

### 4. Update deployment to target specific node

Replace the node name with an actual node from your cluster:

```bash
kubectl patch deployment hostname-node-selector -p '{"spec":{"template":{"spec":{"nodeName":"ip-10-0-2-161.ec2.internal"}}}}'
```

## Part 2: Affinity and Anti-Affinity

### 5. Test node affinity

Deploy pods with node affinity rules:

```bash
kubectl apply -f hostname-affinity-deployment.yaml
```

### 6. Test pod anti-affinity

Deploy pods with anti-affinity rules to spread across nodes:

```bash
kubectl apply -f hostname-antiaffinity-deployment.yaml
```

### 7. Review pod distribution

```bash
kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name
```

**Expected output example:**
```
NODE                         NAME
ip-10-0-3-172.ec2.internal   hostname-affinity-699bffc99b-7gvnq
ip-10-0-3-172.ec2.internal   hostname-affinity-699bffc99b-m8zjf
ip-10-0-3-172.ec2.internal   hostname-affinity-699bffc99b-ngxqj
ip-10-0-2-244.ec2.internal   hostname-anti-affinity-54dcf744b4-58frh
ip-10-0-3-172.ec2.internal   hostname-anti-affinity-54dcf744b4-6jdlb
ip-10-0-3-172.ec2.internal   hostname-anti-affinity-54dcf744b4-ltsz5
ip-10-0-2-244.ec2.internal   hostname-node-selector-8668c8cb75-wk7n6
```

## Part 3: Taints and Tolerations

### 8. Identify the busiest node

Find the node with the most pods:

```bash
export TOP_NODE=$(kubectl get pod -o=custom-columns=NODE:.spec.nodeName --no-headers | sort | uniq -c | sort -r | awk '{print $2}' | head -n1)
echo ${TOP_NODE}
```

### 9. Monitor pod movement

Run this command in a visible shell to watch pod changes:

```bash
kubectl get pods -o wide -w
```

### 10. Apply taint to the node

```bash
kubectl taint nodes ${TOP_NODE} area=vip:NoExecute
```

### 11. Inspect the tainted node

```bash
kubectl describe node ${TOP_NODE}
```

### 12. Observe pod eviction

Check what happened to the pods on the tainted node:

```bash
kubectl get pods -o wide
```

### 13. Deploy pods that tolerate the taint

```bash
kubectl apply -f hostname-toleration-deployment.yaml
```

### 14. Verify toleration works

The new pods should be able to run on the tainted node.

## Cleanup

Remove all resources and node taints:

```bash
kubectl delete -f .
kubectl taint nodes ${TOP_NODE} area=vip:NoExecute-
```

## Key Concepts

- **Node Selector**: Simple key-value matching for node selection
- **Node Affinity**: More expressive node selection with required/preferred rules
- **Pod Affinity**: Schedule pods near other pods
- **Pod Anti-Affinity**: Schedule pods away from other pods
- **Taints**: Mark nodes as unsuitable for certain pods
- **Tolerations**: Allow pods to be scheduled on tainted nodes

## Scheduling Rules Comparison

| Method | Use Case | Flexibility |
|--------|----------|-------------|
| Node Selector | Simple node targeting | Low |
| Node Affinity | Complex node rules | High |
| Pod Affinity | Co-location of pods | High |
| Pod Anti-Affinity | Pod separation | High |
| Taints/Tolerations | Node specialization | Medium |

## Best Practices

- Use anti-affinity for high availability
- Use affinity for performance optimization
- Combine multiple scheduling rules for complex requirements
- Test scheduling rules in development environments
- Consider resource requirements alongside scheduling rules

## Troubleshooting

- Use `kubectl describe pod` to see scheduling failures
- Check node labels with `kubectl get nodes --show-labels`
- Verify taint syntax: `key=value:effect`
- Remember to remove taints during cleanup
