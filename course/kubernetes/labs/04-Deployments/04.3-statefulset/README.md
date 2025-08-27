# StatefulSet Lab - MySQL

## Overview

This lab demonstrates Kubernetes StatefulSets, which are designed for stateful applications that require stable network identities, persistent storage, and ordered deployment/scaling. You'll deploy MySQL as a StatefulSet and connect it to WordPress.

## Prerequisites

- A running Kubernetes cluster with dynamic volume provisioning
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes Deployments, Services, and Persistent Volumes
- A default StorageClass configured in your cluster

## Lab Objectives

- Deploy a MySQL database using StatefulSet
- Understand StatefulSet characteristics (stable network identity, persistent storage)
- Use ephemeral containers for debugging
- Connect WordPress to the StatefulSet MySQL
- Compare StatefulSets with Deployments

## Instructions

### 1. Check existing storage resources

```bash
kubectl get -n default pvc,pv,storageclass
```

### 2. Set default StorageClass (if needed)

```bash
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 3. Deploy MySQL StatefulSet

```bash
kubectl apply -f mysql-sts.yaml
```

### 4. Verify StatefulSet deployment

```bash
kubectl get statefulset
kubectl get pods -l app=mysql
kubectl get pvc
```

### 5. Check for any deployment issues

```bash
kubectl describe pod mysql-0
```

### 6. Debug using ephemeral containers

Use ephemeral containers to connect to the MySQL database:

```bash
kubectl debug pod/mysql-0 --image=mysql -ti -- mysql -h 127.0.0.1 -padmin
```

This demonstrates the ephemeral container feature for debugging running pods.

### 7. Deploy WordPress connected to StatefulSet MySQL

```bash
kubectl apply -f wordpress-deployment.yaml
```

### 8. Get the WordPress service endpoint

```bash
kubectl get svc wordpress
```

### 9. Test the complete application

Access WordPress through the LoadBalancer endpoint and verify it can connect to the MySQL StatefulSet.

## Cleanup

Remove all resources created in this lab:

```bash
kubectl delete -f .
```

**Note**: StatefulSet PVCs are not automatically deleted and may need manual cleanup.

## Key Concepts

- **StatefulSet**: Manages stateful applications with stable network identities
- **Ordered Deployment**: Pods are created, updated, and deleted in order
- **Stable Network Identity**: Each pod gets a predictable hostname (mysql-0, mysql-1, etc.)
- **Persistent Storage**: Each pod gets its own persistent volume
- **Ephemeral Containers**: Temporary containers for debugging purposes

## StatefulSet vs Deployment

| Feature | StatefulSet | Deployment |
|---------|-------------|------------|
| Pod Names | Predictable (mysql-0, mysql-1) | Random |
| Storage | Per-pod persistent volumes | Shared or ephemeral |
| Deployment Order | Sequential | Parallel |
| Use Case | Databases, clustered apps | Stateless applications |

## Troubleshooting

- If the StatefulSet pod is stuck in `Pending`, check StorageClass and PVC status
- Ensure your cluster has dynamic volume provisioning enabled
- For debugging, use ephemeral containers or `kubectl logs` to inspect issues