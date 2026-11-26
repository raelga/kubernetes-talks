# WordPress with MySQL Deployment Lab

## Overview

This lab demonstrates how to deploy a multi-tier application (WordPress with MySQL) using Kubernetes Deployments. You'll learn about persistent storage, secrets management, and how data persistence works with Persistent Volume Claims (PVCs).

## Prerequisites

- A running Kubernetes cluster with dynamic volume provisioning
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes Deployments, Services, and Persistent Volumes

## Lab Objectives

- Deploy MySQL database with and without persistent storage
- Deploy WordPress application connected to MySQL
- Understand the importance of persistent storage for stateful applications
- Practice secrets management for database credentials
- Observe data persistence behavior

## Instructions

### 1. Deploy MySQL without persistent storage

```bash
kubectl apply -f mysql-deployment.yaml
```

### 2. Check for deployment issues

```bash
kubectl describe pod -l app=mysql
```

This will likely show issues due to missing secrets.

### 3. Deploy database credentials

```bash
kubectl apply -f mysql-credentials-secret.yaml
```

### 4. Deploy WordPress with persistent storage

```bash
kubectl apply -f wordpress-deployment.yaml
```

### 5. Get the WordPress service endpoint

```bash
kubectl get svc wordpress
```

On a cloud cluster, wait for the LoadBalancer external IP/hostname. On Kind,
run `kubectl port-forward svc/wordpress 8080:80` in another terminal and open
<http://localhost:8080>. Wait for `kubectl rollout status deployment/mysql`
and `kubectl rollout status deployment/wordpress`, then complete the WordPress
setup and create a post so there is database-backed data to check.

### 6. Test data persistence - Delete MySQL pod

```bash
kubectl delete pod -l app=mysql
kubectl rollout status deployment/mysql
```

### 7. Check the application

Visit the WordPress URL. You'll notice that all MySQL-backed data is gone because we didn't use persistent storage for MySQL.

### 8. Deploy MySQL with persistent storage

```bash
kubectl apply -f mysql-deployment-pvc.yaml
```

This version includes a new, initially empty PVC; it does not migrate the
ephemeral database. Wait for MySQL to start, complete WordPress setup again,
and create a post before testing persistence. Both MySQL manifests use
`Recreate` to avoid running two database instances against the same volume.

```bash
kubectl rollout status deployment/mysql
```

### 9. Delete the MySQL pod again

```bash
kubectl delete pod -l app=mysql
kubectl rollout status deployment/mysql
```

### 10. Verify data persistence

Check the application again. This time, MySQL data should persist in the PVC and be available to the new pod.

## Cleanup

Remove all resources created in this lab:

```bash
kubectl delete -f . --ignore-not-found
```

This removes the PVCs too; their backing data may be deleted according to the
StorageClass reclaim policy. This lab uses example credentials only.

## Key Concepts

- **Persistent Volume Claims (PVCs)**: Requests for storage by pods
- **Secrets**: Secure way to store sensitive information like passwords
- **Multi-tier Applications**: Applications with multiple components (frontend, backend, database)
- **Data Persistence**: Ensuring data survives pod restarts and failures
- **StatefulSets vs Deployments**: When to use each for different types of applications

## Troubleshooting

- If pods are in `Pending` state, check if storage classes are available
- If MySQL pods fail to start, verify the secret is created correctly
- For LoadBalancer services, ensure your cluster supports external load balancers
