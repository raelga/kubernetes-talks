# Deployment Lab - Cats Application

## Overview

This lab demonstrates Kubernetes Deployments, which provide declarative updates for Pods and ReplicaSets. Unlike ReplicaSets, Deployments offer additional features like rolling updates, rollback capabilities, and deployment strategies.

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes pods, ReplicaSets, and labels

## Lab Objectives

- Deploy an application using Kubernetes Deployments
- Expose the application using a Service
- Perform rolling updates to different application versions
- Observe deployment behavior and pod lifecycle
- Practice cleanup operations

## Instructions

### 1. Deploy the initial application version

```bash
kubectl apply -f cats.yaml
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

### 4. Monitor the deployment

Open a new terminal and run the following command to watch pod changes in real-time:

```bash
watch kubectl get pods
```

### 5. Deploy the "lia" version with monitoring

```bash
kubectl apply -f lia.yaml
watch kubectl get pods
```

### 6. Deploy the "liam" version with monitoring

```bash
kubectl apply -f liam.yaml
watch kubectl get pods
```

## Cleanup

Remove all resources created in this lab:

```bash
kubectl delete all -l app=cats
```

## Key Concepts

- **Deployment**: Provides declarative updates to Pods and ReplicaSets
- **Rolling Updates**: Gradually replaces old pods with new ones
- **Deployment Strategy**: Controls how updates are rolled out
- **Revision History**: Deployments maintain a history for rollback purposes

## Additional Commands

Check deployment status:
```bash
kubectl rollout status deployment/cats
```

View deployment history:
```bash
kubectl rollout history deployment/cats
```
