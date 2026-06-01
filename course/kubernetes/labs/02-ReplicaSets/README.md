# ReplicaSets Lab

## Table of Contents

- [ReplicaSets Lab](#replicasets-lab)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Learning Objectives](#learning-objectives)
  - [Introduction](#introduction)
    - [Learn more](#learn-more)
    - [Some notes](#some-notes)
  - [1 - Create a `ReplicaSet`](#1---create-a-replicaset)
  - [2 - Scaling `ReplicaSets`](#2---scaling-replicasets)
    - [Double the number of replicas with `kubectl scale`](#double-the-number-of-replicas-with-kubectl-scale)
    - [Scale back to 1 replica](#scale-back-to-1-replica)
    - [Update the `ReplicaSet` with the yaml definition](#update-the-replicaset-with-the-yaml-definition)
    - [Scale to 50 replicas](#scale-to-50-replicas)
    - [Scale down back to 5 replicas](#scale-down-back-to-5-replicas)
    - [Pod adoption](#pod-adoption)
    - [Overlapping selectors](#overlapping-selectors)
  - [3 - Selectors and Pods](#3---selectors-and-pods)
    - [Deploy some **blue** pods](#deploy-some-blue-pods)
    - [Deploy a **blue** `ReplicaSet`](#deploy-a-blue-replicaset)
    - [Run a _red_ pod](#run-a-red-pod)
    - [`ReplicaSet` for non-colored pods only](#replicaset-for-non-colored-pods-only)
    - [Let's acquire those fancy orange `pods`](#lets-acquire-those-fancy-orange-pods)
    - [Remove a pod from the orange replicaset](#remove-a-pod-from-the-orange-replicaset)
    - [Clean up](#clean-up)
  - [4 - Container probes](#4---container-probes)
    - [Readiness probe](#readiness-probe)
    - [Liveness probe](#liveness-probe)
    - [Liveness probe only (failing)](#liveness-probe-only-failing)
    - [Both probes (failing)](#both-probes-failing)
    - [Both probes (working)](#both-probes-working)
    - [Clean up](#clean-up-1)
  - [5 - Manual rolling update](#5---manual-rolling-update)
    - [Deploy the initial `ReplicaSet`](#deploy-the-initial-replicaset)
    - [Update the `ReplicaSet` pod template](#update-the-replicaset-pod-template)
    - [Update the `ReplicaSet` `Pod` template with the fixed `ReadinessProbe`](#update-the-replicaset-pod-template-with-the-fixed-readinessprobe)
    - [Clean up the failing versions and the old ones](#clean-up-the-failing-versions-and-the-old-ones)

## Overview

This lab provides hands-on experience with Kubernetes ReplicaSets, covering creation, scaling, selectors, probes, and manual rolling updates. You'll learn how ReplicaSets manage Pod replicas and understand their limitations for application deployments.

## Prerequisites

- Kubernetes cluster access (local or remote)
- `kubectl` command-line tool configured
- Basic understanding of Kubernetes Pods
- Familiarity with YAML syntax

## Learning Objectives

By the end of this lab, you will be able to:

- Create and manage ReplicaSets
- Scale ReplicaSets up and down
- Understand ReplicaSet selectors and Pod ownership
- Configure container probes (readiness and liveness)
- Perform manual rolling updates with ReplicaSets
- Recognize the limitations of ReplicaSets for deployments

## Introduction

> **ReplicaSet Definition:**
> 
> A ReplicaSet is defined with fields, including a selector that specifies how to identify Pods it can acquire, a number of replicas indicating how many Pods it should be maintaining, and a pod template specifying the data of new Pods it should create to meet the number of replicas criteria. A ReplicaSet then fulfills its purpose by creating and deleting Pods as needed to reach the desired number. When a ReplicaSet needs to create new Pods, it uses its Pod template.

### Learn more

- [ReplicaSet Concepts](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- [ReplicaSet API Reference](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/replica-set-v1/)

### Some notes

- Kubernetes is fast, especially when working with lightweight containers, so to see what is happening, we'll need to run `kubectl` commands quickly.

That's why we will run the `kubectl` command to apply changes and, if it works, immediately after, a `kubectl get` with the `-w, --watch` flag:

`-w, --watch=false: After listing/getting the requested object, watch for changes. Uninitialized objects are excluded if no object name is provided.`

This will allow us to get information on what is happening just after the command is applied:

```bash
kubectl run sleepy --image bash:5.0 --restart=Never -- sleep 10 && kubectl get pods sleepy -w
pod/sleepy created
NAME     READY   STATUS              RESTARTS   AGE
sleepy   0/1     ContainerCreating   0          0s
sleepy   1/1     Running             0          1s
sleepy   0/1     Completed           0          12s
```

This command creates a `Pod` called `sleepy` with a container using the image `bash:5.0` and running a `sleep 10`. Once the first command completes, `kubectl get pods sleepy -w` will `watch` the `Pod` and print a new line for each status change.

## 1 - Create a `ReplicaSet`

Create the `ReplicaSet` object:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: cats-gatet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cats
  template:
    metadata:
      labels:
        app: cats
    spec:
      containers:
      
      - name: cats
        image: raelga/cats:gatet
```

Apply the YAML:

```bash
kubectl apply -f 101_simple-rs.yaml
replicaset.apps/cats-gatet created
```

```bash
kubectl get pods
NAME           READY   STATUS              RESTARTS   AGE
cats-gatet-hfsgg   0/1     ContainerCreating   0          3s
```

```bash
kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
cats-gatet-hfsgg   1/1     Running   0          32s
```

```bash
kubectl get rs cats-gatet
NAME     DESIRED   CURRENT   READY   AGE
cats-gatet   1         1         1       29s
```

## 2 - Scaling `ReplicaSets`

### Double the number of replicas with `kubectl scale`

```bash
kubectl scale rs/cats-gatet --replicas 2
replicaset.apps/cats-gatet scaled
```

```bash
kubectl get rs cats-gatet
NAME     DESIRED   CURRENT   READY   AGE
cats-gatet   2         2         2       104s
```

```bash
kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
cats-gatet-hfsgg   1/1     Running   0          74s
cats-gatet-kj8k8   1/1     Running   0          3s
```

### Scale back to 1 replica

```bash
kubectl scale rs/cats-gatet --replicas 1
replicaset.apps/cats-gatet scaled
```

```
kubectl get pods
NAME           READY   STATUS        RESTARTS   AGE
cats-gatet-s8n2f   1/1     Terminating   0          48s
cats-gatet-hfsgg   1/1     Running       0          119s
```

```
kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
cats-gatet-hfsgg   1/1     Running   0          125s
```

### Update the `ReplicaSet` with the yaml definition

We also add information about the resources needed by the app container of the pod, to let the scheduler know how many pods can fit into a node.

```diff
kubectl diff -f 201_simple-rs-5.yaml 
diff -u -N /tmp/LIVE-860683615/apps.v1.ReplicaSet.default.cats-gatet /tmp/MERGED-116908338/apps.v1.ReplicaSet.default.cats-gatet
--
- /tmp/LIVE-860683615/apps.v1.ReplicaSet.default.cats-gatet       2019-05-11 11:05:20.751504492 +0000
+++ /tmp/MERGED-116908338/apps.v1.ReplicaSet.default.cats-gatet     2019-05-11 11:05:20.767506423 +0000
@@ -5,14 +5,14 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"name":"cats-gatet","namespace":"default"},"spec":{"replicas":1,"selector":{"matchLabels":{"app":"cats"}},"template":{"metadata":{"labels":{"app":"cats"}},"spec":{"containers":[{"image":"raelga/cats:gatet","name":"cats"}]}}}}
   creationTimestamp: "2019-05-11T11:01:50Z"

-  generation: 3
+  generation: 4
   name: cats-gatet
   namespace: default
   resourceVersion: "1560"
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-gatet
   uid: 2db859ed-73dc-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 1
+  replicas: 5
   selector:
     matchLabels:
       app: cats
@@ -26,7 +26,13 @@
       
       - image: raelga/cats:gatet
         imagePullPolicy: IfNotPresent
         name: cats

-        resources: {}
+        resources:
+          limits:
+            cpu: "1"
+            memory: 100Mi
+          requests:
+            cpu: 100m
+            memory: 50Mi
         terminationMessagePath: /dev/termination-log
         terminationMessagePolicy: File
       dnsPolicy: ClusterFirst
exit status 1
```

```bash
kubectl apply -f 201_simple-rs-5.yaml && kubectl get pods -w
replicaset.apps/cats-gatet configured
NAME           READY   STATUS              RESTARTS   AGE
cats-gatet-dgksp   0/1     ContainerCreating   0          0s
cats-gatet-hfsgg   1/1     Running             0          4m58s
cats-gatet-xxxxx   0/1     ContainerCreating   0          0s
cats-gatet-xxxxx   0/1     ContainerCreating   0          0s
cats-gatet-xxxxx   0/1     ContainerCreating   0          0s
cats-gatet-xxxxx   1/1     Running             0          2s
cats-gatet-xxxxx   1/1     Running             0          3s
cats-gatet-dgksp   1/1     Running             0          4s
cats-gatet-xxxxx   1/1     Running             0          4s
```

```
kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
cats-gatet-dgksp   1/1     Running   0          10s
cats-gatet-hfsgg   1/1     Running   0          5m8s
cats-gatet-xxxxx   1/1     Running   0          10s
cats-gatet-xxxxx   1/1     Running   0          10s
cats-gatet-xxxxx   1/1     Running   0          10s
```

### Scale to 50 replicas

```diff
kubectl diff -f 202_simple-rs-50.yaml
diff -u -N /tmp/LIVE-082216881/apps.v1.ReplicaSet.default.cats-gatet /tmp/MERGED-524798300/apps.v1.ReplicaSet.default.cats-gatet
--
- /tmp/LIVE-082216881/apps.v1.ReplicaSet.default.cats-gatet       2019-05-11 11:09:06.426174215 +0000
+++ /tmp/MERGED-524798300/apps.v1.ReplicaSet.default.cats-gatet     2019-05-11 11:09:06.440175724 +0000
@@ -5,14 +5,14 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"name":"cats-gatet","namespace":"default"},"spec":{"replicas":5,"selector":{"matchLabels":{"app":"cats"}},"template":{"metadata":{"labels":{"app":"cats"}},"spec":{"containers":[{"image":"raelga/cats:gatet","name":"cats","resources":{"limits":{"cpu":"1","memory":"100Mi"},"requests":{"cpu":"50m","memory":"50Mi"}}}]}}}}
   creationTimestamp: "2019-05-11T11:01:50Z"

-  generation: 9
+  generation: 10
   name: cats-gatet
   namespace: default
   resourceVersion: "2292"
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-gatet
   uid: 2db859ed-73dc-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 5
+  replicas: 50
   selector:
     matchLabels:
       app: cats
exit status 1
```

```bash
kubectl apply -f 202_simple-rs-50.yaml && kubectl get rs cats-gatet -w
replicaset.apps/cats-gatet configured
NAME     DESIRED   CURRENT   READY   AGE
cats-gatet   50        5         5       12m
cats-gatet   50        5         5       12m
cats-gatet   50        50        5       12m
cats-gatet   50        50        6       12m
cats-gatet   50        50        7       12m
cats-gatet   50        50        8       12m
cats-gatet   50        50        9       12m
cats-gatet   50        50        10      12m
cats-gatet   50        50        11      12m
cats-gatet   50        50        12      12m
cats-gatet   50        50        13      12m
cats-gatet   50        50        14      12m
cats-gatet   50        50        15      12m
cats-gatet   50        50        16      12m
cats-gatet   50        50        17      12m
cats-gatet   50        50        18      12m
cats-gatet   50        50        19      13m
cats-gatet   50        50        20      13m
cats-gatet   50        50        21      13m
cats-gatet   50        50        22      13m
cats-gatet   50        50        23      13m
cats-gatet   50        50        24      13m
cats-gatet   50        50        25      13m
cats-gatet   50        50        26      13m
cats-gatet   50        50        27      13m
cats-gatet   50        50        28      13m
cats-gatet   50        50        29      13m
cats-gatet   50        50        30      13m
cats-gatet   50        50        31      13m
cats-gatet   50        50        32      13m
cats-gatet   50        50        33      13m
cats-gatet   50        50        34      13m
cats-gatet   50        50        35      13m
```

Check the pods that are not `Running`:

```bash
kubectl get pods --field-selector='status.phase!=Running'
NAME           READY   STATUS    RESTARTS   AGE
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          38s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          38s
cats-gatet-xxxxx   0/1     Pending   0          39s
cats-gatet-xxxxx   0/1     Pending   0          39s
```

```bash
kubectl describe $(kubectl get pods --field-selector='status.phase!=Running' --output name | head -n1)
Name:               cats-gatet-xxxxx
Namespace:          default
Priority:           0
PriorityClassName:  <none>
Node:               <none>
Labels:             app=cats
Annotations:        <none>
Status:             Pending
IP:                 
Controlled By:      ReplicaSet/cats-gatet
Containers:
  app:
    Image:      raelga/cats:gatet
    Port:       <none>
    Host Port:  <none>
    Limits:
      cpu:     1
      memory:  100Mi
    Requests:
      cpu:        100m
      memory:     50Mi
    Environment:  <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-5mrjx (ro)
Conditions:
  Type           Status
  PodScheduled   False 
Volumes:
  default-token-5mrjx:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-5mrjx
    Optional:    false
QoS Class:       Burstable
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason            Age                From               Message
  ----     ------            ----               ----               -------
  Warning  FailedScheduling  59s (x2 over 59s)  default-scheduler  0/2 nodes are available: 2 Insufficient cpu.
```

We can see that the *Pod* cannot be scheduled due to insufficient CPUs in the node pool.

`Warning  FailedScheduling  41s (x6 over 3m58s)  default-scheduler  0/2 nodes are available: 2 Insufficient cpu.`

### Scale down back to 5 replicas

```bash
kubectl scale rs/cats-gatet --replicas 5 && kubectl get rs/cats-gatet -w
replicaset.apps/cats-gatet scaled
NAME     DESIRED   CURRENT   READY   AGE
cats-gatet   5         50        35      34m
cats-gatet   5         50        35      34m
cats-gatet   5         5         5       34m
```

```
kubectl get pods  
NAME           READY   STATUS    RESTARTS   AGE
cats-gatet-hfsgg   1/1     Running   0          34m
cats-gatet-hzhpc   1/1     Running   0          22m
cats-gatet-wjdf9   1/1     Running   0          22m
cats-gatet-xgq2x   1/1     Running   0          22m
cats-gatet-xh5hm   1/1     Running   0          22m
```

### Pod adoption

A ReplicaSet doesn't just create pods — it also **adopts existing pods** that match its selector. If pods with the right labels already exist when a ReplicaSet is created, the ReplicaSet takes ownership of them.

First, delete the ReplicaSet and create 5 standalone pods with the `app: cats` label:

```bash
kubectl delete rs cats-gatet
kubectl apply -f 203_simple-rs-pods.yaml
```

```
pod/cats-gatet-pod-1 created
pod/cats-gatet-pod-2 created
pod/cats-gatet-pod-3 created
pod/cats-gatet-pod-4 created
pod/cats-gatet-pod-5 created
```

These pods have no owner — they're standalone:

```bash
kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind
```

```
NAME           OWNER
cats-gatet-pod-1   <none>
cats-gatet-pod-2   <none>
cats-gatet-pod-3   <none>
cats-gatet-pod-4   <none>
cats-gatet-pod-5   <none>
```

Now create the ReplicaSet with 3 replicas:

```bash
kubectl apply -f 201_simple-rs-5.yaml && kubectl get pods -l app=cats -w
```

The ReplicaSet adopts all 5 existing pods and doesn't need to create new ones (5 available >= 5 desired). If we had set `replicas: 3`, it would adopt 3 and terminate 2.

```bash
kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind
```

```
NAME           OWNER
cats-gatet-pod-1   ReplicaSet
cats-gatet-pod-2   ReplicaSet
cats-gatet-pod-3   ReplicaSet
cats-gatet-pod-4   ReplicaSet
cats-gatet-pod-5   ReplicaSet
```

All pods are now owned by the ReplicaSet.

### Overlapping selectors

What happens when two ReplicaSets use the **same selector**? You might expect the second one to "see" the first one's pods and do nothing. Let's test it.

Create the first ReplicaSet with 3 replicas using `app: cats`:

```bash
kubectl delete rs cats-gatet
kubectl apply -f 210_simple-rs-overlap-a.yaml && kubectl wait --for=condition=Ready pod -l app=cats --timeout=60s
```

```
replicaset.apps/cats-broad created
```

Now create a second ReplicaSet with the **same selector** (`app: cats`) and also 3 replicas, but using a different image:

```bash
kubectl apply -f 211_simple-rs-overlap-b.yaml
```

```
replicaset.apps/cats-also created
```

Check the pods:

```bash
kubectl get pods -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image,OWNER:.metadata.ownerReferences[0].name'
```

```
NAME                 IMAGE               OWNER
cats-also-6ntsf    raelga/cats:liam    cats-also
cats-also-dr6nm    raelga/cats:liam    cats-also
cats-also-zllvk    raelga/cats:liam    cats-also
cats-broad-dqrlp   raelga/cats:gatet   cats-broad
cats-broad-ntqp7   raelga/cats:gatet   cats-broad
cats-broad-qgbbq   raelga/cats:gatet   cats-broad
```

**6 pods total**, not 3. Each ReplicaSet created its own set of pods. Even though both selectors match all 6 pods, Kubernetes uses `ownerReferences` to track which controller owns which pod. A ReplicaSet **only counts pods it owns**, not all pods matching its selector.

This is an important distinction: **label selectors find pods, but ownership determines control**.

Clean up before the next section:

```bash
kubectl delete rs cats-gatet-broad cats-also
```

## 3 - Selectors and Pods

### Deploy some **blue** pods

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: cats-liam-pod-1
  labels:
    app: cats
    cat: liam
spec:
  containers:
    
    - name: cats
      image: raelga/cats:liam
...
```

```bash
kubectl apply -f 301_cats-liam-pods.yaml && kubectl get pods -w
pod/cats-liam-pod-1 created
pod/cats-liam-pod-2 created
pod/cats-liam-pod-3 created
NAME                READY   STATUS        RESTARTS   AGE
cats-liam-pod-1   0/1     Terminating   0          1s
cats-liam-pod-2   0/1     Terminating   0          0s
cats-liam-pod-3   0/1     Terminating   0          0s
cats-gatet-hfsgg        1/1     Running       0          107m
cats-gatet-hzhpc        1/1     Running       0          95m
cats-gatet-wjdf9        1/1     Running       0          95m
cats-gatet-xgq2x        1/1     Running       0          95m
cats-gatet-xh5hm        1/1     Running       0          95m
cats-liam-pod-3   0/1     Terminating   0          2s
cats-liam-pod-3   0/1     Terminating   0          2s
cats-liam-pod-1   0/1     Terminating   0          5s
cats-liam-pod-1   0/1     Terminating   0          5s
cats-liam-pod-2   0/1     Terminating   0          11s
cats-liam-pod-2   0/1     Terminating   0          11s
```

```bash
kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
cats-gatet-hfsgg   1/1     Running   0          108m
cats-gatet-hzhpc   1/1     Running   0          96m
cats-gatet-wjdf9   1/1     Running   0          96m
cats-gatet-xgq2x   1/1     Running   0          96m
cats-gatet-xh5hm   1/1     Running   0          96m
```

The new *blue* pods get `Terminated`! Why??

```bash
kubectl describe rs/cats-gatet
Name:         cats-gatet
Namespace:    default
Selector:     app=cats
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"name":"cats-gatet","namespace":"default"},"spec":{"replicas":50,"sel...
Replicas:     5 current / 5 desired
Pods Status:  5 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=cats
  Containers:
   app:
    Image:      raelga/cats:gatet
    Port:       <none>
    Host Port:  <none>
    Limits:
      cpu:     1
      memory:  100Mi
    Requests:
      cpu:        100m
      memory:     50Mi
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Events:
  Type    Reason            Age   From                   Message
  ---
  -    -----
  -            ---
  -  ---
  -                   -------
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: cats-liam-pod-1
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: cats-liam-pod-2
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: cats-liam-pod-3
```

We can see that the `ReplicaSet` terminated those *Pods*:

```
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: cats-liam-pod-1
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: cats-liam-pod-2
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: cats-liam-pod-3
```

### Deploy a **blue** `ReplicaSet`

```bash
kubectl apply -f 302_cats-liam-rs.yaml && kubectl get pods -w
replicaset.apps/cats-liam created
NAME                READY   STATUS              RESTARTS   AGE
cats-liam-cff2b   0/1     Pending             0          0s
cats-liam-dp26t   0/1     Pending             0          0s
cats-liam-kfl7z   0/1     Pending             0          0s
cats-liam-kr46r   0/1     Pending             0          0s
cats-liam-nng6p   0/1     ContainerCreating   0          0s
cats-gatet-hfsgg        1/1     Running             0          112m
cats-gatet-hzhpc        1/1     Running             0          100m
cats-gatet-wjdf9        1/1     Running             0          100m
cats-gatet-xgq2x        1/1     Running             0          100m
cats-gatet-xh5hm        1/1     Running             0          100m
cats-liam-kfl7z   0/1     ContainerCreating   0          0s
cats-liam-dp26t   0/1     ContainerCreating   0          0s
cats-liam-cff2b   0/1     ContainerCreating   0          0s
cats-liam-kr46r   0/1     ContainerCreating   0          0s
cats-liam-cff2b   1/1     Running             0          2s
cats-liam-kfl7z   1/1     Running             0          3s
cats-liam-nng6p   1/1     Running             0          4s
cats-liam-kr46r   1/1     Running             0          4s
cats-liam-dp26t   1/1     Running             0          4s
```

```
kubectl get pods
NAME                READY   STATUS    RESTARTS   AGE
cats-liam-cff2b   1/1     Running   0          11s
cats-liam-dp26t   1/1     Running   0          11s
cats-liam-kfl7z   1/1     Running   0          11s
cats-liam-kr46r   1/1     Running   0          11s
cats-liam-nng6p   1/1     Running   0          11s
cats-gatet-hfsgg        1/1     Running   0          112m
cats-gatet-hzhpc        1/1     Running   0          100m
cats-gatet-wjdf9        1/1     Running   0          100m
cats-gatet-xgq2x        1/1     Running   0          100m
cats-gatet-xh5hm        1/1     Running   0          100m
```

```
kubectl get rs
NAME          DESIRED   CURRENT   READY   AGE
cats-gatet        5         5         5       112m
cats-liam   5         5         5       34s
```

Now the *Pods* stay, but why?

The selector is matching sets of pods, from most restrictive to less restrictive. So `rs/cats-gatet` will manage all pods with label: `app: cats` that don't match any other ReplicaSet.

### Run a _red_ pod

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: cats-red-pod-1
  labels:
    app: cats
    cat: red
spec:
  containers:
    
    - name: cats
      image: raelga/cats:liam
```

This new *Pods*, have a color label. Will be deleted?

```bash
kubectl apply -f 303_cats-red-pods.yaml && kubectl get pods -w
pod/cats-red-pod-1 created
NAME                READY   STATUS        RESTARTS   AGE
cats-liam-cff2b   1/1     Running       0          75s
cats-liam-dp26t   1/1     Running       0          75s
cats-liam-kfl7z   1/1     Running       0          75s
cats-liam-kr46r   1/1     Running       0          75s
cats-liam-nng6p   1/1     Running       0          75s
cats-gatet-hfsgg        1/1     Running       0          113m
cats-gatet-hzhpc        1/1     Running       0          101m
cats-red-pod-1    0/1     Terminating   0          0s
cats-gatet-wjdf9        1/1     Running       0          101m
cats-gatet-xgq2x        1/1     Running       0          101m
cats-gatet-xh5hm        1/1     Running       0          101m
cats-red-pod-1    0/1     Terminating   0          7s
cats-red-pod-1    0/1     Terminating   0          7s
```

```
kubectl describe rs cats-gatet | grep cats-red-pod
  Normal  SuccessfulDelete  46s    replicaset-controller  Deleted pod: cats-red-pod-1
```

The **red** `Pod` is killed because:


- Has the `app: cats` label selector

- There is no any `ReplicaSet` for the `cat: red` pods

This pods matches `cats-gatet` `ReplicaSet` selector and there is already 5 pods pods matching the selector, so should be terminated.

### `ReplicaSet` for non-colored pods only

The new selector for the `rs/cats-gatet-nocolor` will be a combination of a label and an expresion:

```yaml
  selector:
    matchLabels:
      app: cats
    matchExpressions:
      
      - { key: cat, operator: DoesNotExist }
```

Let's try to update the `cats-gatet` `ReplicaSet`:

```diff
kubectl diff -f 304_simple-rs-nocolor-update.yaml 
The ReplicaSet "cats-gatet" is invalid: spec.selector: Invalid value: v1.LabelSelector{MatchLabels:map[string]string{"app":"cats"}, MatchExpressions:[]v1.LabelSelectorRequirement{v1.LabelSelectorRequirement{Key:"color", Operator:"DoesNotExist", Values:[]string(nil)}}}: field is immutable
```

`ReplicaSets` are defined by the `.spec.selectors` and are immutable.

Let's create a new `ReplicaSet` then:

```
kubectl apply -f 305_cats-nocolor-rs.yaml
replicaset.apps/cats-nocolor created
```

```
kubectl get rs
NAME             DESIRED   CURRENT   READY   AGE
cats-gatet           5         5         5       121m
cats-liam      5         5         5       9m38s
cats-nocolor   5         5         5       16s
```

Let's create some orange `Pods`:

```
kubectl apply -f 306_cats-lia-pods.yaml && kubectl get pods -w -l cat=lia
pod/cats-lia-pod-1 created
pod/cats-lia-pod-2 created
pod/cats-lia-pod-3 created
NAME                  READY   STATUS        RESTARTS   AGE
cats-lia-pod-1   0/1     Terminating   0          0s
cats-lia-pod-2   0/1     Terminating   0          0s
cats-lia-pod-3   0/1     Terminating   0          0s
```

They are still getting deleted by the `rs/cats-gatet` controller.

```
kubectl describe rs cats-gatet | grep orange        
  Normal  SuccessfulDelete  33s (x3 over 89s)  replicaset-controller  Deleted pod: cats-lia-pod-1
  Normal  SuccessfulDelete  33s (x3 over 89s)  replicaset-controller  Deleted pod: cats-lia-pod-2
  Normal  SuccessfulDelete  33s (x3 over 89s)  replicaset-controller  Deleted pod: cats-lia-pod-3
```

Let's remove the `cats-gatet` `ReplicaSet` then:

```bash
kubectl delete rs/cats-gatet            
replicaset.apps "cats-gatet" deleted
```

```
kubectl get rs          
NAME             DESIRED   CURRENT   READY   AGE
cats-liam      5         5         5       12m
cats-nocolor   5         5         5       3m32s
```

Let's create again the orange `Pods`.

```
kubectl apply -f 306_cats-lia-pods.yaml && kubectl get pods -w -l cat=lia
pod/cats-lia-pod-1 created
pod/cats-lia-pod-2 created
pod/cats-lia-pod-3 created
NAME                  READY   STATUS              RESTARTS   AGE
cats-lia-pod-1   0/1     ContainerCreating   0          1s
cats-lia-pod-2   0/1     ContainerCreating   0          1s
cats-lia-pod-3   0/1     ContainerCreating   0          0s
cats-lia-pod-2   1/1     Running             0          3s
cats-lia-pod-3   1/1     Running             0          4s
cats-lia-pod-1   1/1     Running             0          7s
```

```
kubectl get pods
NAME                   READY   STATUS    RESTARTS   AGE
cats-liam-cff2b      1/1     Running   0          13m
cats-liam-dp26t      1/1     Running   0          13m
cats-liam-kfl7z      1/1     Running   0          13m
cats-liam-kr46r      1/1     Running   0          13m
cats-liam-nng6p      1/1     Running   0          13m
cats-nocolor-pcf6d   1/1     Running   0          3m58s
cats-nocolor-qfn9l   1/1     Running   0          3m58s
cats-nocolor-rlkdl   1/1     Running   0          3m58s
cats-nocolor-txglk   1/1     Running   0          3m58s
cats-nocolor-vmxm5   1/1     Running   0          3m58s
cats-lia-pod-1    1/1     Running   0          11s
cats-lia-pod-2    1/1     Running   0          11s
cats-lia-pod-3    1/1     Running   0          10s
```

### Let's acquire those fancy orange `pods`

```bash
kubectl apply -f 307_cats-lia-rs.yaml
replicaset.apps/cats-lia created
```

```
kubectl get pods -l cat=lia
NAME                  READY   STATUS    RESTARTS   AGE
cats-lia-k72nq   1/1     Running   0          23s
cats-lia-mlh9h   1/1     Running   0          23s
cats-lia-pod-1   1/1     Running   0          2m14s
cats-lia-pod-2   1/1     Running   0          2m14s
cats-lia-pod-3   1/1     Running   0          2m13s
cats-lia-vkclj   1/1     Running   0          23s
```

As you can see, the `ReplicaSet` only created the required pods to have 6 replicas:

```
kubectl describe rs cats-gatet-orange | grep SuccessfulCreate
  Normal  SuccessfulCreate  67s   replicaset-controller  Created pod: cats-lia-mlh9h
  Normal  SuccessfulCreate  67s   replicaset-controller  Created pod: cats-lia-k72nq
  Normal  SuccessfulCreate  67s   replicaset-controller  Created pod: cats-lia-vkclj
```

### Remove a pod from the orange replicaset

```
kubectl patch pod cats-lia-pod-1 --type='json' --patch='[{"op":"replace", "path":"/metadata/labels/color", "value":"pink"}]' && kubectl get pods -w -l cat=lia
pod/cats-lia-pod-1 patched
NAME                  READY   STATUS              RESTARTS   AGE
cats-lia-5s295   1/1     Running             0          4m2s
cats-lia-6nd67   0/1     ContainerCreating   0          0s
cats-lia-gzwjs   1/1     Running             0          4m3s
cats-lia-pod-2   1/1     Running             0          4m6s
cats-lia-pod-3   1/1     Running             0          4m6s
cats-lia-v9lsm   1/1     Running             0          4m2s
cats-lia-6nd67   1/1     Running             0          2s
```

The `cats-lia-pod-1` is no longer part of the `ReplicaSet` and the `cats-lia-6nd67` has been created to ensure that there are 6 replicas running.

```
kubectl patch pod cats-lia-pod-2 --type='json' --patch='[{"op":"replace", "path":"/metadata/labels/color", "value":"pink"}]' && kubectl get rs cats-gatet-orange -w
pod/cats-lia-pod-2 patched
NAME            DESIRED   CURRENT   READY   AGE
cats-lia   6         6         5       8m13s
cats-lia   6         6         6       8m15s
```

```
kubectl get pods -l color=pink
NAME                  READY   STATUS    RESTARTS   AGE
cats-lia-pod-1   1/1     Running   0          9m21s
cats-lia-pod-2   1/1     Running   0          9m21s
```

### Clean up

```bash
kubectl delete rs cats-gatet-blue cats-nocolor cats-lia
replicaset.apps "cats-liam" deleted
replicaset.apps "cats-nocolor" deleted
replicaset.apps "cats-lia" deleted
```

```
kubectl get pods
NAME                  READY   STATUS    RESTARTS   AGE
cats-lia-pod-1   1/1     Running   0          9m50s
cats-lia-pod-2   1/1     Running   0          9m50s
```

```
kubectl delete pods -l color=pink 
pod "cats-lia-pod-1" deleted
pod "cats-lia-pod-2" deleted
```

```
kubectl get pods
No resources found.
```

## 4 - Container probes

### Readiness probe

Let's add a `ReadinessProbe`, on the port 80:


- Wait 10 secs before start probing

- Each 5 seconds, check the probe

- Mark as healthy after 3 consecutive OK checks

```yaml
...
    spec:
      containers:
      
      - name: cats
        image: raelga/cats:neu
        readinessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          successThreshold: 3
```

```bash
kubectl apply -f 400_probes-rs-readiness.yaml && kubectl get pods -w -l app=cats
replicaset.apps/probes created
NAME           READY   STATUS              RESTARTS   AGE
probes-m2l5h   0/1     ContainerCreating   0          0s
probes-x56j5   0/1     ContainerCreating   0          0s
probes-m2l5h   0/1     Running             0          2s
probes-x56j5   0/1     Running             0          4s
probes-x56j5   1/1     Running             0          24s
probes-m2l5h   1/1     Running             0          24s
```

After about 25 seconds, the `Pods` became `READY`:


- Scheduling time (From `Pending` to `Running`)

- 10 seconds of `initialDelaySeconds`

- 15 seconds (5 `periodSeconds` x 3 `successThreshold`)

Deploy some `Pods` with failing ReadinessProbes:

```bash
kubectl apply -f 401_probes-rs-readiness-ko.yaml && kubectl get pods -l app=cats -w
replicaset.apps/probes configured
NAME           READY   STATUS              RESTARTS   AGE
probes-csqfn   0/1     ContainerCreating   0          0s
probes-m2l5h   1/1     Running             0          51s
probes-np7vg   0/1     Pending             0          0s
probes-x56j5   1/1     Running             0          51s
probes-np7vg   0/1     ContainerCreating   0          0s
probes-csqfn   0/1     Running             0          2s
probes-np7vg   0/1     Running             0          3s
```

They are not getting `READY` at all:

```
kubectl get pods -l app=cats
NAME           READY   STATUS    RESTARTS   AGE
probes-csqfn   0/1     Running   0          86s
probes-m2l5h   1/1     Running   0          2m17s
probes-np7vg   0/1     Running   0          86s
probes-x56j5   1/1     Running   0          2m17s
```

And if we look the status of the `READY 0/1` pods, we'll see the reason in the `Events:` section:

```
kubectl describe pods $(kubectl get pods | sed -n 's:\(\S\+\)\s\+0/1.*:\1:p') | grep Warning
  Warning  Unhealthy  2s (x17 over 82s)  kubelet, cnbcn-k8s-study-jam-np-fw7y  Readiness probe failed: dial tcp 10.244.1.225:81: connect: connection refused
  Warning  Unhealthy  0s (x17 over 80s)  kubelet, cnbcn-k8s-study-jam-np-fw7x  Readiness probe failed: dial tcp 10.244.0.55:81: connect: connection refused
```

```
kubectl describe pods $(kubectl get pods | sed -n 's:\(\S\+\)\s\+0/1.*:\1:p')
...
Events:
  Type     Reason     Age                From                                  Message
  ---
  -     -----
  -     ---
  -               ---
  -                                  -------
  Normal   Scheduled  109s               default-scheduler                     Successfully assigned default/probes-np7vg to cnbcn-k8s-study-jam-np-fw7x
  Normal   Pulled     107s               kubelet, cnbcn-k8s-study-jam-np-fw7x  Container image "raelga/cats:neu" already present on machine
  Normal   Created    107s               kubelet, cnbcn-k8s-study-jam-np-fw7x  Created container
  Normal   Started    107s               kubelet, cnbcn-k8s-study-jam-np-fw7x  Started container
  Warning  Unhealthy  3s (x19 over 93s)  kubelet, cnbcn-k8s-study-jam-np-fw7x  Readiness probe failed: dial tcp 10.244.0.55:81: connect: connection refused
```

The good thing, is the failing `Pods` never get `READY` and won't receive any traffic.

### Liveness probe

Let's add a `LivenessProbe`, on the port 80:


- Wait 10 secs before start probing

- Each 5 seconds, check the probe

- Mark as unhealthy after 2 consecutive failed checks

```yaml
...
    spec:
      containers:
      
      - name: cats
        image: raelga/cats:neu
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 2
```

```bash
kubectl apply -f 402_probes-rs-liveness.yaml && kubectl get pods -l app=cats -w
replicaset.apps/probes configured
NAME           READY   STATUS              RESTARTS   AGE
probes-csqfn   0/1     Running             0          2m19s
probes-hhn5x   0/1     ContainerCreating   0          0s
probes-m2l5h   1/1     Running             0          3m10s
probes-np7vg   0/1     Running             0          2m19s
probes-ntl94   0/1     ContainerCreating   0          0s
probes-x56j5   1/1     Running             0          3m10s
probes-hhn5x   1/1     Running             0          2s
probes-ntl94   1/1     Running             0          2s
```

The `Pods` using the `LivenessProbe` get `READY` in a few seconds, just when the container starts and responds the first probe request. Why don't we check the `failureThreshold` instead of the `successThreshold`?

Because this only checks that the application is live, and if fails, will restart the container instead of keep re-checking untill the application to become ready again.

Let's launch a failing `LivenessProbe` to see this behavior:

```bash
kubectl apply -f 403_probes-rs-liveness-ko.yaml && kubectl get pods -l app=cats -w
replicaset.apps/probes configured
NAME           READY   STATUS              RESTARTS   AGE
probes-csqfn   0/1     Running             0          7m10s
probes-fzbgb   0/1     Pending             0          0s
probes-hhn5x   1/1     Running             0          4m51s
probes-m2l5h   1/1     Running             0          8m1s
probes-np7vg   0/1     Running             0          7m10s
probes-ntl94   1/1     Running             0          4m51s
probes-tmlln   0/1     ContainerCreating   0          0s
probes-x56j5   1/1     Running             0          8m1s
probes-fzbgb   0/1     ContainerCreating   0          0s
probes-fzbgb   0/1     Running             0          3s
probes-tmlln   0/1     Running             0          3s
probes-tmlln   0/1     Running             1          19s
probes-fzbgb   0/1     Running             1          20s
probes-tmlln   1/1     Running             1          33s
probes-tmlln   0/1     Running             2          34s
probes-fzbgb   1/1     Running             1          34s
probes-fzbgb   0/1     Running             2          40s
probes-tmlln   1/1     Running             2          48s
probes-tmlln   0/1     Running             3          50s
probes-fzbgb   1/1     Running             2          54s
probes-fzbgb   0/1     Running             3          61s
probes-tmlln   1/1     Running             3          63s
probes-tmlln   0/1     CrashLoopBackOff    3          65s
probes-fzbgb   1/1     Running             3          74s
probes-fzbgb   0/1     Running             4          80s
probes-tmlln   0/1     Running             4          94s
probes-fzbgb   1/1     Running             4          94s
probes-fzbgb   0/1     CrashLoopBackOff    4          100s
probes-tmlln   1/1     Running             4          108s
probes-tmlln   0/1     Running             5          109s
probes-tmlln   1/1     Running             5          2m3s
probes-tmlln   0/1     CrashLoopBackOff    5          2m5s
probes-fzbgb   0/1     Running             5          2m28s
probes-fzbgb   1/1     Running             5          2m39s
probes-fzbgb   0/1     CrashLoopBackOff    5          2m45s
probes-tmlln   0/1     Running             6          3m27s
probes-tmlln   1/1     Running             6          3m38s
probes-tmlln   0/1     CrashLoopBackOff    6          3m44s
probes-fzbgb   0/1     Running             6          4m14s
probes-fzbgb   1/1     Running             6          4m24s
probes-fzbgb   0/1     CrashLoopBackOff    6          4m31s
```

A `CrashloopBackOff` means that we have a pod starting, crashing, starting again, and then crashing again. Failed containers that are restarted by the kubelet are restarted with an exponential back-off delay (10s, 20s, 40s …) capped at five minutes, and is reset after ten minutes of successful execution.

### Liveness probe only (failing)

What happens when we have a liveness probe that fails but **no readiness probe**? The pods show as READY (because there's no readiness check) but keep restarting:

```bash
kubectl delete rs cats-neu
kubectl apply -f 404_probes-rs-liveness-ko.yaml && kubectl get pods -l app=cats -w --sort-by=.metadata.creationTimestamp
```

The `--sort-by=.metadata.creationTimestamp` flag sorts pods by creation time, making it easier to follow the sequence. All 12 pods will become READY briefly, then start restarting as the liveness probe hits `/bad-endpoint` (returns 404):

```
NAME             READY   STATUS    RESTARTS      AGE
cats-neu-xxxxx   1/1     Running   0             15s
cats-neu-xxxxx   1/1     Running   1 (2s ago)    25s
cats-neu-xxxxx   1/1     Running   2 (2s ago)    35s
```

Without a readiness probe, these failing pods would still receive traffic — a dangerous situation in production.

### Both probes (failing)

Now let's add both a failing readiness probe (wrong port 81) and a failing liveness probe (wrong path):

```bash
kubectl apply -f 405_probes-rs-both-ko.yaml && kubectl get pods -l app=cats -w --sort-by=.metadata.creationTimestamp
```

The pods are **not READY** (readiness probe fails on port 81) **and** keep restarting (liveness probe fails on `/bad-endpoint`). This is the worst case — pods are in a restart loop and never serve traffic.

### Both probes (working)

Finally, let's fix both probes — readiness on the correct port 80, liveness on the correct path `/`:

```bash
kubectl apply -f 406_probes-rs-both-ok.yaml && kubectl get pods -l app=cats -w --sort-by=.metadata.creationTimestamp
```

```
NAME             READY   STATUS    RESTARTS   AGE
cats-neu-xxxxx   0/1     Running   0          5s
cats-neu-xxxxx   1/1     Running   0          25s
```

All pods become READY after ~25 seconds (10s `initialDelaySeconds` + 3 × 5s `successThreshold` × `periodSeconds`) and stay healthy with zero restarts.

### Clean up

```bash
kubectl delete rs cats-neu && kubectl get pods -w -l app=cats
replicaset.apps "probes" deleted
NAME           READY   STATUS        RESTARTS   AGE
probes-csqfn   0/1     Terminating   0          29m
probes-fzbgb   0/1     Terminating   11         22m
probes-hhn5x   1/1     Terminating   0          27m
probes-m2l5h   1/1     Terminating   0          30m
probes-np7vg   0/1     Terminating   0          29m
probes-ntl94   1/1     Terminating   0          27m
probes-tmlln   0/1     Terminating   11         22m
probes-x56j5   1/1     Terminating   0          30m
probes-x56j5   0/1     Terminating   0          30m
probes-ntl94   0/1     Terminating   0          27m
probes-np7vg   0/1     Terminating   0          30m
probes-csqfn   0/1     Terminating   0          30m
probes-hhn5x   0/1     Terminating   0          27m
probes-m2l5h   0/1     Terminating   0          30m
probes-m2l5h   0/1     Terminating   0          30m
probes-tmlln   0/1     Terminating   11         22m
probes-tmlln   0/1     Terminating   11         22m
probes-csqfn   0/1     Terminating   0          30m
probes-csqfn   0/1     Terminating   0          30m
probes-hhn5x   0/1     Terminating   0          27m
probes-hhn5x   0/1     Terminating   0          27m
probes-fzbgb   0/1     Terminating   11         22m
probes-fzbgb   0/1     Terminating   11         22m
probes-m2l5h   0/1     Terminating   0          30m
probes-m2l5h   0/1     Terminating   0          30m
probes-x56j5   0/1     Terminating   0          30m
probes-x56j5   0/1     Terminating   0          30m
probes-ntl94   0/1     Terminating   0          27m
probes-ntl94   0/1     Terminating   0          27m
probes-np7vg   0/1     Terminating   0          30m
probes-np7vg   0/1     Terminating   0          30m
```

```
kubectl get pods
No resources found.
```

## 5 - Manual rolling update

### Deploy the initial `ReplicaSet`

```bash
kubectl apply -f 501_cats-neu-rs.yaml && kubectl get pods -l app=cats -w
replicaset.apps/cats-neu created
NAME                  READY   STATUS    RESTARTS   AGE
cats-neu-dtfv4   0/1     Pending   0          0s
cats-neu-jnck4   0/1     Pending   0          0s
cats-neu-dtfv4   0/1     Pending   0          0s
cats-neu-h5wsz   0/1     Pending   0          0s
cats-neu-h5wsz   0/1     Pending   0          0s
cats-neu-jnck4   0/1     Pending   0          0s
cats-neu-dtfv4   0/1     ContainerCreating   0          0s
cats-neu-jnck4   0/1     ContainerCreating   0          0s
cats-neu-h5wsz   0/1     ContainerCreating   0          0s
cats-neu-h5wsz   0/1     Running             0          2s
cats-neu-jnck4   0/1     Running             0          3s
cats-neu-dtfv4   0/1     Running             0          3s
cats-neu-h5wsz   1/1     Running             0          7s
cats-neu-jnck4   1/1     Running             0          7s
cats-neu-dtfv4   1/1     Running             0          10s
```

Let's list the pods running, including the name of the first container image, using `custom-columns` output format: 

`-o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime`

```
kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime
NAME                  IMAGE             STATUS    STARTED
cats-neu-dtfv4   raelga/cats:neu   Running   2019-05-11T16:20:36Z
cats-neu-h5wsz   raelga/cats:neu   Running   2019-05-11T16:20:36Z
cats-neu-jnck4   raelga/cats:neu   Running   2019-05-11T16:20:36Z
```

### Update the `ReplicaSet` pod template

Let's update the `ReplicaSet` `Pod` template and include a new template, that will fail the `ReadinessProbe`.

```diff
kubectl diff -f 502_cats-neu-rs-update-image-ko.yaml 
diff -u -N /tmp/LIVE-839052409/apps.v1.ReplicaSet.default.cats-neu /tmp/MERGED-353118084/apps.v1.ReplicaSet.default.cats-neu
--
- /tmp/LIVE-839052409/apps.v1.ReplicaSet.default.cats-neu        2019-05-11 16:21:15.916702182 +0000
+++ /tmp/MERGED-353118084/apps.v1.ReplicaSet.default.cats-neu      2019-05-11 16:21:15.929703344 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"cats-neu"},"name":"cats-neu","namespace":"default"},"spec":{"replicas":3,"selector":{"matchLabels":{"app":"cats-neu"}},"template":{"metadata":{"labels":{"app":"cats-neu"}},"spec":{"containers":[{"image":"raelga/cats:neu","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"cats","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 1
+  generation: 2
   labels:
     app: cats
   name: cats-neu
@@ -25,7 +25,7 @@
         app: cats
     spec:
       containers:

-      
- image: raelga/cats:neu
+      
- image: raelga/cats:blanca
         imagePullPolicy: IfNotPresent
         livenessProbe:
           failureThreshold: 2
@@ -41,7 +41,7 @@
         readinessProbe:
           failureThreshold: 3
           httpGet:

-            path: /
+            path: /bad-endpoint
             port: 80
             scheme: HTTP
           initialDelaySeconds: 2
exit status 1
```

```bash
kubectl apply -f 502_cats-neu-rs-update-image-ko.yaml && kubectl get pods -l app=cats -w
replicaset.apps/cats-neu configured
NAME                  READY   STATUS    RESTARTS   AGE
cats-neu-dtfv4   1/1     Running   0          56s
cats-neu-h5wsz   1/1     Running   0          56s
cats-neu-jnck4   1/1     Running   0          56s
```

Nothing happens, as the `ReplicaSet` only cares for the number of replicas, the new `Pod` template will be used for creating new `Pods` when required, but has no effect on the existing `ReplicaSet` `Pods`.

```
kubectl get rs cats-neu
NAME            DESIRED   CURRENT   READY   AGE
cats-neu   3         3         3       20m
```

Let's increase the number of replicas to 6:

```diff
kubectl diff -f 503_cats-neu-rs-6-update-image-ko.yaml 
diff -u -N /tmp/LIVE-648056706/apps.v1.ReplicaSet.default.cats-neu /tmp/MERGED-796264697/apps.v1.ReplicaSet.default.cats-neu
--
- /tmp/LIVE-648056706/apps.v1.ReplicaSet.default.cats-neu        2019-05-11 16:23:07.606688192 +0000
+++ /tmp/MERGED-796264697/apps.v1.ReplicaSet.default.cats-neu      2019-05-11 16:23:07.619689354 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"cats-neu"},"name":"cats-neu","namespace":"default"},"spec":{"replicas":3,"selector":{"matchLabels":{"app":"cats-neu"}},"template":{"metadata":{"labels":{"app":"cats-neu"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"cats","readinessProbe":{"httpGet":{"path":"/bad-endpoint","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 2
+  generation: 3
   labels:
     app: cats
   name: cats-neu
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-neu
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 3
+  replicas: 6
   selector:
     matchLabels:
       app: cats
exit status 1
```

Now the start but never get `READY`, as they are not passing the `ReadinessProbe`:

```bash
kubectl apply -f 503_cats-neu-rs-6-update-image-ko.yaml && kubectl get pods -l app=cats -w
replicaset.apps/cats-neu configured
NAME                  READY   STATUS              RESTARTS   AGE
cats-neu-42vbb   0/1     ContainerCreating   0          0s
cats-neu-dhs88   0/1     ContainerCreating   0          0s
cats-neu-dtfv4   1/1     Running             0          3m21s
cats-neu-fhrlp   0/1     ContainerCreating   0          0s
cats-neu-h5wsz   1/1     Running             0          3m21s
cats-neu-jnck4   1/1     Running             0          3m21s
cats-neu-dhs88   0/1     Running             0          2s
cats-neu-42vbb   0/1     Running             0          2s
cats-neu-fhrlp   0/1     Running             0          2s
```

At this point, the old image is still running and serving requests. The new version is failing, but never gets traffic, as is not passing the `ReadinessProbe`.

```
kubectl get rs cats-neu
NAME            DESIRED   CURRENT   READY   AGE
cats-neu   6         6         3       4m25s
```

```
kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime
NAME                  IMAGE                STATUS    STARTED
cats-neu-42vbb   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
cats-neu-dhs88   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
cats-neu-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-fhrlp   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
cats-neu-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
```

We can see the `ReadinessProbe` error using `kubectl describe`:

```
kubectl describe pods -l app=cats | grep Warning
  Warning  Unhealthy  9s (x19 over 3m9s)  kubelet, cnbcn-k8s-study-jam-np-fw7x  Readiness probe failed: HTTP probe failed with statuscode: 404
  Warning  Unhealthy  3s (x19 over 3m3s)  kubelet, cnbcn-k8s-study-jam-np-fw7y  Readiness probe failed: HTTP probe failed with statuscode: 404
  Warning  Unhealthy  1s (x20 over 3m11s)  kubelet, cnbcn-k8s-study-jam-np-fw7x  Readiness probe failed: HTTP probe failed with statuscode: 404
```

### Update the `ReplicaSet` `Pod` template with the fixed `ReadinessProbe`

```diff
kubectl diff -f 504_cats-neu-rs-9-update-image-ok.yaml 
diff -u -N /tmp/LIVE-210527442/apps.v1.ReplicaSet.default.cats-neu /tmp/MERGED-362151945/apps.v1.ReplicaSet.default.cats-neu
--
- /tmp/LIVE-210527442/apps.v1.ReplicaSet.default.cats-neu        2019-05-11 16:30:04.733986406 +0000
+++ /tmp/MERGED-362151945/apps.v1.ReplicaSet.default.cats-neu      2019-05-11 16:30:04.746987569 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"cats-neu"},"name":"cats-neu","namespace":"default"},"spec":{"replicas":6,"selector":{"matchLabels":{"app":"cats-neu"}},"template":{"metadata":{"labels":{"app":"cats-neu"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"cats","readinessProbe":{"httpGet":{"path":"/bad-endpoint","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 3
+  generation: 4
   labels:
     app: cats
   name: cats-neu
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-neu
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 6
+  replicas: 9
   selector:
     matchLabels:
       app: cats
@@ -41,7 +41,7 @@
         readinessProbe:
           failureThreshold: 3
           httpGet:

-            path: /bad-endpoint
+            path: /
             port: 80
             scheme: HTTP
           initialDelaySeconds: 2
exit status 1
```

```bash
kubectl apply -f 504_cats-neu-rs-9-update-image-ok.yaml && kubectl get rs cats-neu -w
replicaset.apps/cats-neu configured
NAME            DESIRED   CURRENT   READY   AGE
cats-neu   9         9         3       11m
cats-neu   9         9         4       11m
cats-neu   9         9         5       11m
cats-neu   9         9         6       11m
```

The `ReplicaSet` now has 9 replicas, 6 of them with the new image:

```
kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime
NAME                  IMAGE                STATUS    STARTED
cats-neu-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-dhs88   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
cats-neu-fhrlp   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
cats-neu-42vbb   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
cats-neu-7g9cc   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
cats-neu-r87pj   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
cats-neu-ssxzx   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
```

And the last 3 replicas, with the fixed `ReadinessProbe`, are `READY`:

```
kubectl get pods --sort-by=.status.startTime
NAME                  READY   STATUS    RESTARTS   AGE
cats-neu-jnck4   1/1     Running   0          12m
cats-neu-dtfv4   1/1     Running   0          12m
cats-neu-h5wsz   1/1     Running   0          12m
cats-neu-dhs88   0/1     Running   0          9m7s
cats-neu-fhrlp   0/1     Running   0          9m7s
cats-neu-42vbb   0/1     Running   0          9m7s
cats-neu-7g9cc   1/1     Running   0          60s
cats-neu-r87pj   1/1     Running   0          60s
cats-neu-ssxzx   1/1     Running   0          60s
```

The new `ReplicaSet` template is creating healthy `Pods`!

### Clean up the failing versions and the old ones

Now, let's clean up the failing `Pods` by scaling back to 6!

```bash
kubectl scale rs/cats-neu --replicas 6
replicaset.apps/cats-neu scaled
```

```
kubectl get pods
NAME                  READY   STATUS        RESTARTS   AGE
cats-neu-42vbb   0/1     Terminating   0          13m
cats-neu-7g9cc   1/1     Running       0          5m27s
cats-neu-dhs88   0/1     Terminating   0          13m
cats-neu-dtfv4   1/1     Running       0          16m
cats-neu-fhrlp   0/1     Terminating   0          13m
cats-neu-h5wsz   1/1     Running       0          16m
cats-neu-jnck4   1/1     Running       0          16m
cats-neu-r87pj   1/1     Running       0          5m27s
cats-neu-ssxzx   1/1     Running       0          5m27s
```

```
kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime
NAME                  IMAGE                STATUS    STARTED
cats-neu-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-7g9cc   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
cats-neu-r87pj   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
cats-neu-ssxzx   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
```

Let's now clean the old version by scaling back to 3!

```bash
kubectl scale rs/cats-neu --replicas 3    
replicaset.apps/cats-neu scaled
```

```
kubectl get pods
NAME                  READY   STATUS        RESTARTS   AGE
cats-neu-dtfv4   1/1     Running       0          20m
cats-neu-h5wsz   1/1     Running       0          20m
cats-neu-jnck4   1/1     Running       0          20m
cats-neu-r87pj   0/1     Terminating   0          9m13s
cats-neu-ssxzx   0/1     Terminating   0          9m13s
```

Wow! It removed the new ones instead of the old ones! Why?

In the first scenario, the `ReplicaSet` saw that some of the replicas weren't `READY` and removed then. But now, both the ones with the new image and the ones with the old are healthy, so in that scenario, will remove always the newest ones.

[pkg/controller/replicaset/replica_set.go:getPodsToDelete](https://github.com/kubernetes/kubernetes/blob/ed2bdd53dc6f44f36f7912ed0e1a7e5ba800151b/pkg/controller/replicaset/replica_set.go#L684)
```go
func getPodsToDelete(filteredPods []*v1.Pod, diff int) []*v1.Pod {
	// No need to sort pods if we are about to delete all of them.
	// diff will always be <= len(filteredPods), so not need to handle > case.
	if diff < len(filteredPods) {
		// Sort the pods in the order such that not-ready < ready, unscheduled
		// < scheduled, and pending < running. This ensures that we delete pods
		// in the earlier stages whenever possible.
		sort.Sort(controller.ActivePods(filteredPods))
	}
	return filteredPods[:diff]
}
```

And the code for `ActivePods`:

[pkg/controller/controller_utils.go:ActivePods](https://github.com/kubernetes/kubernetes/blob/ed2bdd53dc6f44f36f7912ed0e1a7e5ba800151b/pkg/controller/controller_utils.go#L735)
```go
func (s ActivePods) Less(i, j int) bool {
	// 1. Unassigned < assigned
	// If only one of the pods is unassigned, the unassigned one is smaller
	if s[i].Spec.NodeName != s[j].Spec.NodeName && (len(s[i].Spec.NodeName) == 0 || len(s[j].Spec.NodeName) == 0) {
		return len(s[i].Spec.NodeName) == 0
	}
	// 2. PodPending < PodUnknown < PodRunning
	m := map[v1.PodPhase]int{v1.PodPending: 0, v1.PodUnknown: 1, v1.PodRunning: 2}
	if m[s[i].Status.Phase] != m[s[j].Status.Phase] {
		return m[s[i].Status.Phase] < m[s[j].Status.Phase]
	}
	// 3. Not ready < ready
	// If only one of the pods is not ready, the not ready one is smaller
	if podutil.IsPodReady(s[i]) != podutil.IsPodReady(s[j]) {
		return !podutil.IsPodReady(s[i])
	}
	// TODO: take availability into account when we push minReadySeconds information from deployment into pods,
	//       see https://github.com/kubernetes/kubernetes/issues/22065
	// 4. Been ready for empty time < less time < more time
	// If both pods are ready, the latest ready one is smaller
	if podutil.IsPodReady(s[i]) && podutil.IsPodReady(s[j]) && !podReadyTime(s[i]).Equal(podReadyTime(s[j])) {
		return afterOrZero(podReadyTime(s[i]), podReadyTime(s[j]))
	}
	// 5. Pods with containers with higher restart counts < lower restart counts
	if maxContainerRestarts(s[i]) != maxContainerRestarts(s[j]) {
		return maxContainerRestarts(s[i]) > maxContainerRestarts(s[j])
	}
	// 6. Empty creation time pods < newer pods < older pods
	if !s[i].CreationTimestamp.Equal(&s[j].CreationTimestamp) {
		return afterOrZero(&s[i].CreationTimestamp, &s[j].CreationTimestamp)
	}
	return false
}
```

Let's scale back to 6, so we will have the 3 replicas with the old version and 3 replicas with the new template:

```diff
diff -u -N /tmp/LIVE-571681951/apps.v1.ReplicaSet.default.cats-neu /tmp/MERGED-052727154/apps.v1.ReplicaSet.default.cats-neu
--
- /tmp/LIVE-571681951/apps.v1.ReplicaSet.default.cats-neu        2019-05-11 16:58:39.800320854 +0000
+++ /tmp/MERGED-052727154/apps.v1.ReplicaSet.default.cats-neu      2019-05-11 16:58:39.823322911 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"cats-neu"},"name":"cats-neu","namespace":"default"},"spec":{"replicas":6,"selector":{"matchLabels":{"app":"cats-neu"}},"template":{"metadata":{"labels":{"app":"cats-neu"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"cats","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 20
+  generation: 21
   labels:
     app: cats
   name: cats-neu
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-neu
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 3
+  replicas: 6
   selector:
     matchLabels:
       app: cats
@@ -23,6 +23,7 @@
       creationTimestamp: null
       labels:
         app: cats
+        version: v2.0
     spec:
       containers:
       
       - image: raelga/cats:blanca
exit status 1
```

```
kubectl apply -f 505_cats-neu-rs-6-update-image-ok.yaml && kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime -w
replicaset.apps/cats-neu configured
NAME                  IMAGE                STATUS    STARTED
cats-neu-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-pbltv   raelga/cats:blanca   Pending   2019-05-11T17:00:12Z
cats-neu-sv698   raelga/cats:blanca   Pending   2019-05-11T17:00:12Z
cats-neu-vbrqc   raelga/cats:blanca   Pending   2019-05-11T17:00:12Z
cats-neu-pbltv   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-sv698   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-vbrqc   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-sv698   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-pbltv   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-vbrqc   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
```

```
kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime
NAME                  IMAGE                STATUS    STARTED
cats-neu-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
cats-neu-pbltv   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-sv698   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-vbrqc   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
```

As we added a new label to the template, is easy to identify the new replicas:

```
kubectl get pods -l app=cats,version=v2.0  
NAME                  READY   STATUS    RESTARTS   AGE
cats-neu-pbltv   1/1     Running   0          55s
cats-neu-sv698   1/1     Running   0          55s
cats-neu-vbrqc   1/1     Running   0          55s
```

And now, we can remove the old version and the `ReplicaSet` will replace the terminated `pods` with new ones, using the `ReplicaSet` template:

```
kubectl get pods -l app=cats,version!=v2.0
NAME                  READY   STATUS    RESTARTS   AGE
cats-neu-dtfv4   1/1     Running   0          41m
cats-neu-h5wsz   1/1     Running   0          41m
cats-neu-jnck4   1/1     Running   0          41m
```

```
kubectl delete  pods -l app=cats,version!=v2.0
pod "cats-neu-dtfv4" deleted
pod "cats-neu-h5wsz" deleted
pod "cats-neu-jnck4" deleted
```

```
 kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime   
NAME                  IMAGE                STATUS    STARTED
cats-neu-pbltv   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-sv698   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-vbrqc   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
cats-neu-62v48   raelga/cats:blanca   Running   2019-05-11T17:02:53Z
cats-neu-bs6z9   raelga/cats:blanca   Running   2019-05-11T17:02:53Z
cats-neu-ndhd7   raelga/cats:blanca   Running   2019-05-11T17:02:53Z
```

```
kubectl get pods -l app=cats,version!=v2.0
No resources found.
```

That worked! The problem, is that now the `ReplicaSet` selector is not the same as the labels defined in the `Pod` template, so another if another `ReplicaSet` is created with the exact match, this `ReplicaSet` will lose the `Pods`.

So let's update the `ReplicaSet` with the new selector!

```diff
diff -U5 505_cats-neu-rs-6-update-image-ok.yaml 506_cats-neu-rs-update-selector.yaml 
--
- 505_cats-neu-rs-6-update-image-ok.yaml 2019-05-11 16:58:45.738851782 +0000
+++ 506_cats-neu-rs-update-selector.yaml   2019-05-11 17:09:35.580954662 +0000
@@ -7,10 +7,11 @@
 spec:
   replicas: 6
   selector:
     matchLabels:
       app: cats
+      version: v2.0
   template:
     metadata:
       labels:
         app: cats
         version: v2.0
```

```
kubectl apply -f 506_cats-neu-rs-update-selector.yaml
The ReplicaSet "cats-neu" is invalid: spec.selector: Invalid value: v1.LabelSelector{MatchLabels:map[string]string{"app":"cats-neu", "version":"v2.0"}, MatchExpressions:[]v1.LabelSelectorRequirement(nil)}: field is immutable
```

As we already saw before, the `ReplicaSet` selector field is `immutable`, so we need to create a new `ReplicaSet`.

```diff
diff -U5 505_cats-neu-rs-6-update-image-ok.yaml 507_cats-blanca-rs.yaml 
--
- 505_cats-neu-rs-6-update-image-ok.yaml 2019-05-11 16:58:45.738851782 +0000
+++ 507_cats-blanca-rs.yaml      2019-05-11 17:09:20.425599538 +0000
@@ -1,16 +1,17 @@
 apiVersion: apps/v1
 kind: ReplicaSet
 metadata:

-  name: cats-neu
+  name: cats-blanca
   labels:
     app: cats
 spec:
   replicas: 6
   selector:
     matchLabels:
       app: cats
+      version: v2.0
   template:
     metadata:
       labels:
         app: cats
         version: v2.0
```

Let's check the current status:

```
kubectl get rs -l app=cats
NAME            DESIRED   CURRENT   READY   AGE
cats-neu   6         6         6       52m
```

Let's add the new `ReplicaSet`!

```
kubectl apply -f 507_cats-blanca-rs.yaml && kubectl get rs -l app=cats -w
replicaset.apps/cats-blanca unchanged
NAME                 DESIRED   CURRENT   READY   AGE
cats-neu        6         6         6       53m
cats-blanca   6         6         2       10s
cats-blanca   6         6         3       10s
cats-blanca   6         6         4       11s
cats-blanca   6         6         5       13s
cats-blanca   6         6         6       14s
```

We changed the `ReplicaSet`, so new replicas have been created with the new `ReplicaSet` name prefix but leave the olds as were generated by another `ReplicaSet`. The ownership information is stored in the `.metadata.ownerReferences` array:

```
 kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels,OWNER-TYPE:.metadata.ownerReferences[0].kind,OWNER-NAME:.metadata.ownerReferences[0].name --sort-by=.status.startTime
NAME                       LABELS                                OWNER-TYPE   OWNER-NAME
cats-neu-pbltv        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-neu-sv698        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-neu-vbrqc        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-neu-62v48        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-neu-bs6z9        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-neu-ndhd7        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-blanca-9kpln   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-blanca-dnl2k   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-blanca-dxj4v   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-blanca-hg8xb   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-blanca-mmvzr   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-blanca-86shb   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
```

We can see, that all the pods have the same `labels`, but are managed by different `ReplicaSets` and they will manage differnt set of `pods` with the same `labels`:

Let's scale down both `ReplicaSets` and see what happens:

```diff
kubectl diff -f 508_cats-neu-scale-down-both-rs.yaml 
diff -u -N /tmp/LIVE-427424072/apps.v1.ReplicaSet.default.cats-neu /tmp/MERGED-238269447/apps.v1.ReplicaSet.default.cats-neu
--
- /tmp/LIVE-427424072/apps.v1.ReplicaSet.default.cats-neu        2019-05-11 17:41:33.346631258 +0000
+++ /tmp/MERGED-238269447/apps.v1.ReplicaSet.default.cats-neu      2019-05-11 17:41:33.360632510 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"cats-neu"},"name":"cats-neu","namespace":"default"},"spec":{"replicas":6,"selector":{"matchLabels":{"app":"cats-neu"}},"template":{"metadata":{"labels":{"app":"cats-neu","version":"v2.0"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"cats","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 23
+  generation: 24
   labels:
     app: cats
   name: cats-neu
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-neu
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 6
+  replicas: 2
   selector:
     matchLabels:
       app: cats
diff -u -N /tmp/LIVE-427424072/apps.v1.ReplicaSet.default.cats-blanca /tmp/MERGED-238269447/apps.v1.ReplicaSet.default.cats-blanca
--
- /tmp/LIVE-427424072/apps.v1.ReplicaSet.default.cats-blanca   2019-05-11 17:41:33.486643786 +0000
+++ /tmp/MERGED-238269447/apps.v1.ReplicaSet.default.cats-blanca 2019-05-11 17:41:33.500645039 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"cats-neu"},"name":"cats-blanca","namespace":"default"},"spec":{"replicas":6,"selector":{"matchLabels":{"app":"cats-neu","version":"v2.0"}},"template":{"metadata":{"labels":{"app":"cats-neu","version":"v2.0"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"cats","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T17:13:37Z"

-  generation: 1
+  generation: 2
   labels:
     app: cats
   name: cats-blanca
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-blanca
   uid: 1d717f4e-7410-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 6
+  replicas: 2
   selector:
     matchLabels:
       app: cats
exit status 1
```

```
kubectl apply -f 508_cats-neu-scale-down-both-rs.yaml && kubectl get pods -w -l app=cats
replicaset.apps/cats-neu configured
replicaset.apps/cats-blanca configured
NAME                       READY   STATUS        RESTARTS   AGE
cats-neu-62v48        1/1     Terminating   0          39m
cats-neu-bs6z9        1/1     Terminating   0          39m
cats-neu-ndhd7        1/1     Terminating   0          39m
cats-neu-pbltv        1/1     Running       0          42m
cats-neu-sv698        1/1     Running       0          42m
cats-blanca-86shb   1/1     Running       0          28m
cats-blanca-9kpln   1/1     Running       0          28m
cats-blanca-dnl2k   1/1     Terminating   0          28m
cats-blanca-dxj4v   1/1     Terminating   0          28m
cats-blanca-hg8xb   1/1     Terminating   0          28m
cats-blanca-mmvzr   1/1     Terminating   0          28m
cats-neu-vbrqc        1/1     Terminating   0          42m
cats-blanca-mmvzr   0/1     Terminating   0          28m
cats-neu-62v48        0/1     Terminating   0          39m
cats-neu-vbrqc        0/1     Terminating   0          42m
cats-neu-bs6z9        0/1     Terminating   0          39m
cats-neu-62v48        0/1     Terminating   0          39m
cats-blanca-dnl2k   0/1     Terminating   0          28m
cats-blanca-dnl2k   0/1     Terminating   0          28m
cats-neu-vbrqc        0/1     Terminating   0          42m
cats-neu-vbrqc        0/1     Terminating   0          42m
cats-neu-vbrqc        0/1     Terminating   0          42m
cats-neu-ndhd7        0/1     Terminating   0          39m
cats-neu-ndhd7        0/1     Terminating   0          39m
cats-neu-62v48        0/1     Terminating   0          39m
cats-blanca-dxj4v   0/1     Terminating   0          28m
cats-neu-62v48        0/1     Terminating   0          39m
cats-blanca-hg8xb   0/1     Terminating   0          28m
cats-neu-bs6z9        0/1     Terminating   0          39m
cats-neu-bs6z9        0/1     Terminating   0          39m
cats-blanca-mmvzr   0/1     Terminating   0          28m
cats-blanca-mmvzr   0/1     Terminating   0          28m
cats-blanca-hg8xb   0/1     Terminating   0          28m
cats-blanca-hg8xb   0/1     Terminating   0          28m
```

```
kubectl get pods -l app=cats 
NAME                       READY   STATUS    RESTARTS   AGE
cats-neu-pbltv        1/1     Running   0          42m
cats-neu-sv698        1/1     Running   0          42m
cats-blanca-86shb   1/1     Running   0          29m
cats-blanca-9kpln   1/1     Running   0          29m
```

```
 kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels,OWNER-TYPE:.metadata.ownerReferences[0].kind,OWNER-NAME:.metadata.ownerReferences[0].name --sort-by=.status.startTime
NAME                       LABELS                                OWNER-TYPE   OWNER-NAME
cats-neu-pbltv        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-neu-sv698        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-blanca-86shb   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-blanca-9kpln   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
```

And now scale both up!

```diff
kubectl diff -f 509_cats-neu-scale-up-both-rs.yaml   
diff -u -N /tmp/LIVE-749110581/apps.v1.ReplicaSet.default.cats-neu /tmp/MERGED-606903056/apps.v1.ReplicaSet.default.cats-neu
--
- /tmp/LIVE-749110581/apps.v1.ReplicaSet.default.cats-neu        2019-05-11 17:43:39.257897487 +0000
+++ /tmp/MERGED-606903056/apps.v1.ReplicaSet.default.cats-neu      2019-05-11 17:43:39.278899367 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"cats-neu"},"name":"cats-neu","namespace":"default"},"spec":{"replicas":2,"selector":{"matchLabels":{"app":"cats-neu"}},"template":{"metadata":{"labels":{"app":"cats-neu","version":"v2.0"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"cats","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 24
+  generation: 25
   labels:
     app: cats
   name: cats-neu
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-neu
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 2
+  replicas: 4
   selector:
     matchLabels:
       app: cats
diff -u -N /tmp/LIVE-749110581/apps.v1.ReplicaSet.default.cats-blanca /tmp/MERGED-606903056/apps.v1.ReplicaSet.default.cats-blanca
--
- /tmp/LIVE-749110581/apps.v1.ReplicaSet.default.cats-blanca   2019-05-11 17:43:39.420912073 +0000
+++ /tmp/MERGED-606903056/apps.v1.ReplicaSet.default.cats-blanca 2019-05-11 17:43:39.440913863 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"cats-neu"},"name":"cats-blanca","namespace":"default"},"spec":{"replicas":2,"selector":{"matchLabels":{"app":"cats-neu","version":"v2.0"}},"template":{"metadata":{"labels":{"app":"cats-neu","version":"v2.0"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"cats","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T17:13:37Z"

-  generation: 2
+  generation: 3
   labels:
     app: cats
   name: cats-blanca
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/cats-blanca
   uid: 1d717f4e-7410-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 2
+  replicas: 4
   selector:
     matchLabels:
       app: cats
exit status 1
```

```
kubectl apply -f 509_cats-neu-scale-up-both-rs.yaml && kubectl get rs -l app=cats -w 
replicaset.apps/cats-neu configured
replicaset.apps/cats-blanca configured
NAME                 DESIRED   CURRENT   READY   AGE
cats-neu        4         4         2       83m
cats-blanca   4         4         2       30m
cats-neu        4         4         3       83m
cats-neu        4         4         4       83m
cats-blanca   4         4         3       30m
cats-blanca   4         4         4       30m
```

```
 kubectl get pods -l app=cats -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels,OWNER-TYPE:.metadata.ownerReferences[0].kind,OWNER-NAME:.metadata.ownerReferences[0].name --sort-by=.status.startTime
NAME                       LABELS                                OWNER-TYPE   OWNER-NAME
cats-neu-pbltv        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-neu-sv698        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-blanca-86shb   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-blanca-9kpln   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-neu-7qtn8        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
cats-blanca-n49jk   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-blanca-szbh4   map[app:cats-neu version:v2.0]   ReplicaSet   cats-blanca
cats-neu-zmdfk        map[app:cats-neu version:v2.0]   ReplicaSet   cats-neu
```

It has become clear that `ReplicaSet` is not meant to be used for `Rolling Updates` or deploying new versions of our application. It is for keeping a number of replicas of a `Pod` running and that's all.

To manage application *deployments*, we need another kind of Kubernetes object that should work with `ReplicaSets`... Lucky for us, Kubernetes has an object for that called... you guessed it... `Deployments`.

## Summary

In this lab, you have learned:

1. **ReplicaSet Basics**: How to create and manage ReplicaSets to maintain a desired number of Pod replicas
2. **Scaling Operations**: How to scale ReplicaSets up and down using `kubectl scale`
3. **Label Selectors**: How ReplicaSets use label selectors to manage Pods and how selector precedence works
4. **Container Probes**: How to configure readiness and liveness probes for health checking
5. **Manual Rolling Updates**: The manual process of updating applications with ReplicaSets and its limitations
6. **ReplicaSet Limitations**: Why ReplicaSets alone are not suitable for application deployments

### Key Takeaways

- ReplicaSets ensure a specified number of Pod replicas are running at any given time
- Label selectors determine which Pods a ReplicaSet manages
- Readiness probes determine when a Pod is ready to receive traffic
- Liveness probes determine when a Pod should be restarted
- Manual rolling updates with ReplicaSets are complex and error-prone
- For production deployments, use Deployments which manage ReplicaSets automatically

### Next Steps

The next logical step is to learn about **Deployments**, which provide:
- Automated rolling updates
- Rollback capabilities
- Update strategies
- Easier application lifecycle management

ReplicaSets are typically managed by higher-level controllers like Deployments rather than being used directly.