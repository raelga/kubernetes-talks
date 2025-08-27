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

Wait for the LoadBalancer to be provisioned and note the external IP/hostname.

### 6. Test data persistence - Delete MySQL pod

```bash
kubectl delete pod -l app=mysql
```

### 7. Check the application

Visit the WordPress URL. You'll notice that all MySQL-backed data is gone because we didn't use persistent storage for MySQL.

### 8. Deploy MySQL with persistent storage

```bash
kubectl apply -f mysql-deployment.yaml
```

This version should include a PVC for data persistence.

### 9. Delete the MySQL pod again

```bash
kubectl delete pod -l app=mysql
```

### 10. Verify data persistence

Check the application again. This time, MySQL data should persist in the PVC and be available to the new pod.

## Cleanup

Remove all resources created in this lab:

```bash
kubectl delete -f .
```

**Note**: PVCs may need to be deleted manually depending on the reclaim policy.

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
