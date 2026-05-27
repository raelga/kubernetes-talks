# Pod Resources

This lab covers how to configure CPU and memory **requests** and **limits** for containers in Kubernetes pods, and how the scheduler uses these values.

## Key concepts

- **Requests**: The amount of CPU/memory the scheduler guarantees to the container. Used for scheduling decisions.
- **Limits**: The maximum amount of CPU/memory the container is allowed to use. Enforced at runtime.
- **QoS Classes**: Kubernetes assigns a Quality of Service class to each pod based on its resource configuration:
  - `Guaranteed` — requests equal limits for all containers
  - `Burstable` — at least one container has a request or limit set, but they are not equal
  - `BestEffort` — no requests or limits set at all

## Pods with requests and limits

To create a pod with both requests and limits set equally, run:

```sh
kubectl apply -f 01-busybox-resources-guaranteed.yaml
```

```
pod/busybox-resources-both created
```

Inspect the pod to see the assigned QoS class:

```sh
kubectl describe pod busybox-resources-both | grep -A1 "QoS\|Limits\|Requests"
```

Since requests and limits are equal (100m CPU, 100Mi memory), the pod gets the `Guaranteed` QoS class.

```
    Limits:
      cpu:     100m
      memory:  100Mi
    Requests:
      cpu:        100m
      memory:     100Mi
QoS Class:                   Guaranteed
```

## Pods with only limits

When only limits are set, Kubernetes automatically sets the requests to match the limits:

```sh
kubectl apply -f 02-busybox-resources-limits-only.yaml
```

```
pod/busybox-resources-limits created
```

```sh
kubectl describe pod busybox-resources-limits | grep -A1 "QoS\|Limits\|Requests"
```

```
    Limits:
      cpu:     100m
      memory:  100Mi
    Requests:
      cpu:        100m
      memory:     100Mi
QoS Class:                   Guaranteed
```

Even though only limits were specified in the manifest, the pod also gets the `Guaranteed` QoS class because Kubernetes copies limits to requests when requests are not set.

## Pods with different requests and limits

When requests are lower than limits, the pod gets the `Burstable` QoS class:

```sh
kubectl apply -f 03-busybox-resources-burstable.yaml
```

```
pod/busybox-resources-requests-0 created
```

```sh
kubectl describe pod busybox-resources-requests-0 | grep -A1 "QoS\|Limits\|Requests"
```

```
    Limits:
      cpu:     1
      memory:  512Mi
    Requests:
      cpu:        25m
      memory:     256Mi
QoS Class:                   Burstable
```

The container is guaranteed 25m CPU and 256Mi memory, but can burst up to 1 CPU and 512Mi memory if available.

## Unschedulable pods

When resource requests exceed the available capacity of all nodes, the pod stays in `Pending` state:

```sh
kubectl apply -f 06-busybox-resources-unschedulable.yaml
```

```
pod/busybox-resources-requests-unschedulable created
```

```sh
kubectl get pod busybox-resources-requests-unschedulable
```

```
NAME                                       READY   STATUS    RESTARTS   AGE
busybox-resources-requests-unschedulable   0/1     Pending   0          5s
```

Check the events to see why the pod is not being scheduled:

```sh
kubectl describe pod busybox-resources-requests-unschedulable | grep -A3 Events
```

```
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  10s   default-scheduler  0/1 nodes are available: 1 Insufficient cpu.
```

The pod requests 4 CPUs, which exceeds what the node can allocate. It will remain `Pending` until enough resources become available.

## Deploying multiple pods with resources

To see how the scheduler distributes pods across available resources, deploy 10 pods at once:

```sh
kubectl apply -f 05-busybox-resources-10.yaml
```

```
pod/busybox-resources-1 created
pod/busybox-resources-2 created
...
pod/busybox-resources-10 created
```

Check the status of all resource pods:

```sh
kubectl get pods -l app=busybox,resources=both
```

Depending on the available resources in the cluster, some pods may end up in `Pending` state because the node cannot satisfy all the requests (each pod requests 512Mi memory).

## Single pod with resources

To see the effect with a single pod from the batch:

```sh
kubectl apply -f 04-busybox-resources-single.yaml
```

This pod requests 25m CPU and 512Mi memory, with limits of 1 CPU and 1024Mi memory, resulting in a `Burstable` QoS class.

## Inspecting resource usage

To see how much resources each pod is actually using (requires metrics-server):

```sh
kubectl top pods -l app=busybox
```

To see the allocatable resources and current allocations on the node:

```sh
kubectl describe node | grep -A5 "Allocated resources"
```

## Cleanup

Delete all the pods created in this lab:

```sh
kubectl delete pod -l app=busybox
```

```
pod "busybox-resources-0" deleted
pod "busybox-resources-1" deleted
...
pod "busybox-resources-both" deleted
pod "busybox-resources-limits" deleted
pod "busybox-resources-requests-0" deleted
pod "busybox-resources-requests-unschedulable" deleted
```
