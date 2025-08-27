# Guestbook Application Deployment Lab

## Overview

This lab demonstrates how to build and deploy a multi-tier web application using Kubernetes and Docker. The guestbook application consists of:

- **Web Frontend**: A web interface for the guestbook
- **Redis Master**: Primary storage for guestbook entries
- **Redis Slaves**: Replicated Redis instances for read scalability

The lab covers container image building, pushing to a registry, deploying multiple application versions, and performing rolling updates.

![Guestbook](guestbook-page.png)

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured to access your cluster
- Docker installed and configured
- A Docker registry account (Docker Hub, ECR, etc.)
- Basic understanding of Kubernetes Deployments and Services

## Lab Objectives

- Build and push container images for multiple application versions
- Deploy a multi-tier application with Redis backend
- Perform rolling updates between application versions
- Practice deployment rollback procedures
- Understand container registry workflows

## Setup

### 1. Docker Registry Login

First, login to your Docker registry. For Docker Hub:

```bash
# Generate a token at: https://hub.docker.com/settings/security?generateToken=true
docker login
```

### 2. Set your Docker registry variable

```bash
export DOCKER_REGISTRY=$(docker info | sed '/Username:/!d;s/.* //') \
  && echo ${DOCKER_REGISTRY}
```

This command should output your Docker registry username.

## Part 1: Version 1 Deployment

### 1. Build the first version

```bash
docker build -t ${DOCKER_REGISTRY}/guestbook:v1 app-v1/
```

### 2. Push v1 to registry

```bash
docker push ${DOCKER_REGISTRY}/guestbook:v1
```

### 3. Deploy the complete application stack

```bash
kubectl apply -f k8s/
```

This deploys:
- Guestbook frontend deployment and service
- Redis master deployment and service  
- Redis slave deployment and service

### 4. Wait for LoadBalancer and access the application

```bash
kubectl get svc guestbook -w
```

Once the external IP is assigned, access the guestbook in your browser.

## Part 2: Version 2 Rolling Update

### 5. Build version 2

```bash
docker build -t ${DOCKER_REGISTRY}/guestbook:v2 app-v2/
```

### 6. Push v2 to registry

```bash
docker push ${DOCKER_REGISTRY}/guestbook:v2
```

### 7. Preview changes before deployment

```bash
kubectl diff -f k8s-v2/
```

This shows what will change (primarily the container image version).

### 8. Deploy v2 using declarative approach

```bash
kubectl apply -f k8s-v2/
```

**Alternative**: Imperative update using kubectl:
```bash
kubectl set image deployment/guestbook guestbook=${DOCKER_REGISTRY}/guestbook:v2
```

### 9. Monitor the rolling update

```bash
kubectl get pods -l app=guestbook -w
```

Observe how Kubernetes gradually replaces v1 pods with v2 pods.

## Part 3: Rollback Operations

### 10. Perform a rollback

```bash
kubectl rollout undo deployment/guestbook
```

### 11. Check rollout status

```bash
kubectl rollout status deployment/guestbook
```

## Part 4: Version 3 Deployment

### 12. Build and push version 3

```bash
docker build -t ${DOCKER_REGISTRY}/guestbook:v3 app-v3/
docker push ${DOCKER_REGISTRY}/guestbook:v3
```

### 13. Deploy v3

```bash
kubectl set image deployment/guestbook guestbook=${DOCKER_REGISTRY}/guestbook:v3
```

### 14. Verify the new version

Check the application in your browser to see the changes in v3.

## Cleanup

Remove all resources created in this lab:

```bash
kubectl delete -f k8s/
```

## Key Concepts

- **Multi-tier Architecture**: Frontend, backend, and data layers
- **Container Registries**: Storing and distributing container images
- **Rolling Updates**: Zero-downtime deployments
- **Rollback**: Reverting to previous application versions
- **Service Discovery**: How components find and communicate with each other

## Deployment Strategies Demonstrated

- **Declarative**: Using `kubectl apply` with YAML manifests
- **Imperative**: Using `kubectl set image` for direct updates
- **Rolling Update**: Default Kubernetes update strategy
- **Rollback**: Reverting to previous deployment revisions

## Best Practices

- Always push images before deploying
- Use specific image tags, avoid `latest`
- Test deployments in staging environments
- Monitor rollout progress
- Have rollback plans ready
- Use consistent naming conventions

## Troubleshooting

- **Image pull errors**: Verify registry credentials and image names
- **Service connectivity**: Check service selectors and pod labels
- **LoadBalancer pending**: Ensure cluster supports external load balancers
- **Rolling update stuck**: Check resource limits and node capacity