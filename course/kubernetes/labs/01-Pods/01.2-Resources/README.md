# Pod Resources

This lab covers how to configure CPU and memory **requests** and **limits** for containers in Kubernetes pods, and how the scheduler uses these values.

## Key concepts

- **Requests**: The CPU/memory amount reserved for scheduling; the scheduler uses it to find a node with sufficient allocatable capacity. Actual runtime availability also depends on node conditions and enforcement.
- **Limits**: The maximum amount of CPU/memory the container is allowed to use. Enforced at runtime.
- **QoS Classes**: Kubernetes assigns a Quality of Service class to each pod based on its resource configuration:
  - `Guaranteed` — every container has CPU and memory requests and limits, with each request equal to its limit
  - `Burstable` — at least one container has a CPU or memory request or limit, but the pod does not meet the `Guaranteed` criteria
  - `BestEffort` — no container has CPU or memory requests or limits

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
kubectl describe pod busybox-resources-both | grep -A3 "QoS\|Limits\|Requests"
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

When a limit is set without a request for the same resource, Kubernetes normally copies the limit to the request, unless admission has supplied a default request:

```sh
kubectl apply -f 02-busybox-resources-limits-only.yaml
```

```
pod/busybox-resources-limits created
```

```sh
kubectl describe pod busybox-resources-limits | grep -A3 "QoS\|Limits\|Requests"
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
kubectl describe pod busybox-resources-requests-0 | grep -A3 "QoS\|Limits\|Requests"
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

The scheduler accounts for 25m CPU and 256Mi memory when placing this container. It can use up to 1 CPU and 512Mi memory when available; CPU is throttled at its limit, whereas exceeding the memory limit can result in an OOM kill.

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

The pod requests 4 CPUs. It remains `Pending` only if no eligible node has at least 4 CPUs and 1000Mi memory available for requests; on a larger cluster it may schedule successfully. To reproduce the pending state, delete the pod, adjust the request above each eligible node's allocatable capacity in a temporary copy of the manifest, and apply that copy. Pod resource requests generally cannot be changed in place. Delete the temporary pod and copy afterwards.

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
kubectl delete -f 01-busybox-resources-guaranteed.yaml -f 02-busybox-resources-limits-only.yaml -f 03-busybox-resources-burstable.yaml -f 04-busybox-resources-single.yaml -f 05-busybox-resources-10.yaml -f 06-busybox-resources-unschedulable.yaml --ignore-not-found
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
