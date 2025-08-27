# ReplicaSet Lab

## Overview

This lab demonstrates how to use Kubernetes ReplicaSets to manage multiple instances of an application. You'll learn how ReplicaSets ensure that a specified number of pod replicas are running at any given time.

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes pods and labels

## Lab Objectives

- Deploy a ReplicaSet with multiple replicas
- Expose the application using a Kubernetes Service
- Test the application deployment
- Observe ReplicaSet behavior when deploying different versions
- Practice cleanup operations

## Instructions

### 1. Deploy the initial application version

```bash
kubectl apply -f cats-replicaset.yaml
```

### 2. Expose the application as a service

```bash
kubectl apply -f service.yaml
```

### 3. Test the deployment

```bash
curl "http://$(kubectl get svc cats \
 -o jsonpath="{.status.loadBalancer.ingress[*]['hostname']}")"
```

### 4. Monitor pod changes

Open a new terminal and run the following command to watch pod changes in real-time:

```bash
watch kubectl get pods
```

### 5. Deploy the "lia" version of the application

```bash
kubectl apply -f lia-rs.yaml
```

### 6. Deploy the "liam" version of the application

```bash
kubectl apply -f liam-rs.yaml
```

## Cleanup

Remove all resources created in this lab:

```bash
kubectl delete all -l app=cats
```

## Key Concepts

- **ReplicaSet**: Ensures that a specified number of pod replicas are running
- **Labels and Selectors**: Used to identify and manage groups of pods
- **Rolling Updates**: ReplicaSets can be used to gradually replace pods with new versions
