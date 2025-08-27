# Jobs and CronJobs Lab

## Overview

This lab demonstrates Kubernetes Jobs and CronJobs, which are designed for running batch workloads and scheduled tasks. You'll learn about different job patterns, the Downward API, and how to schedule recurring jobs.

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes pods and labels

## Lab Objectives

- Deploy a Job with multiple completions
- Understand the difference between `kubectl apply` and `kubectl create` for Jobs
- Explore the Downward API implementation
- Deploy and manage CronJobs
- Monitor job execution and logs

## Instructions

### 1. Deploy a Job with 5 completions

```bash
kubectl apply -f job-5.yaml
```

### 2. Monitor the job execution

```bash
kubectl get pods -l app=hello
kubectl get jobs
```

### 3. Deploy a manual job with generateName

**Note**: Check the Downward API implementation in the job manifest.

First, try with `kubectl apply` (this will fail):

```bash
kubectl apply -f job-manual.yaml
```

This raises an error due to the `generateName` usage. Jobs with `generateName` must be created, not applied.

Now use `kubectl create`:

```bash
kubectl create -f job-manual.yaml
```

### 4. Verify the manually created job

```bash
kubectl get pods -l app=hello
kubectl get jobs
```

### 5. Create multiple manual jobs

You can run the create command multiple times to generate multiple jobs:

```bash
kubectl create -f job-manual.yaml
kubectl create -f job-manual.yaml
```

### 6. Deploy a scheduled CronJob

```bash
kubectl apply -f cronjob.yaml
```

### 7. Monitor the CronJob execution

```bash
kubectl get cronjobs
kubectl get pods -l app=hello -w
```

### 8. View job logs

```bash
kubectl logs -l app=hello --ignore-errors
```

## Cleanup

Remove all resources created in this lab:

```bash
kubectl delete all -l app=hello
```

## Key Concepts

- **Job**: Runs pods to completion, ensures specified number of successful completions
- **CronJob**: Creates Jobs on a scheduled basis using cron syntax
- **generateName**: Generates unique names for resources, requires `kubectl create`
- **Downward API**: Allows containers to access information about themselves and the cluster
- **completions**: Number of successful pod completions required for job success
- **parallelism**: Number of pods running simultaneously

## Job Patterns

| Pattern | Use Case | Configuration |
|---------|----------|---------------|
| Single Job | One-time task | `completions: 1` |
| Parallel Job | Multiple parallel tasks | `parallelism: N` |
| Work Queue | Process items from queue | `completions: N, parallelism: M` |

## CronJob Schedule Examples

- `"0 */6 * * *"` - Every 6 hours
- `"0 9 * * MON"` - Every Monday at 9 AM
- `"*/5 * * * *"` - Every 5 minutes

## Troubleshooting

- Jobs with `generateName` must use `kubectl create`, not `kubectl apply`
- Check job status with `kubectl describe job <job-name>`
- CronJobs respect timezone settings in the cluster
- Failed jobs are retained for debugging (controlled by `failedJobsHistoryLimit`)
