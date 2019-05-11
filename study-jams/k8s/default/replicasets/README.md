# `ReplicaSets`

- [`ReplicaSets`](#replicasets)
  - [Introduction](#introduction)
    - [Learn more](#learn-more)
    - [Some notes](#some-notes)
  - [1 - Create a `ReplicaSet`](#1---create-a-replicaset)
  - [2 - Scaling `ReplicaSets`](#2---scaling-replicasets)
    - [Double the numbers of replicas with `kubectl scale`](#double-the-numbers-of-replicas-with-kubectl-scale)
    - [Scale back to 1 replica](#scale-back-to-1-replica)
    - [Update the `ReplicaSet` with the yaml definition](#update-the-replicaset-with-the-yaml-definition)
    - [Scale to 50 replicas](#scale-to-50-replicas)
    - [Scale down back to 5 replicas](#scale-down-back-to-5-replicas)
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
    - [Clean up](#clean-up-1)
  - [5 - Manual rolling update](#5---manual-rolling-update)
    - [Deploy the initial `ReplicaSet`](#deploy-the-initial-replicaset)
    - [Update the `ReplicaSet` pod template](#update-the-replicaset-pod-template)
    - [Update the `ReplicaSet` `Pod` template with the fixed `ReadinessProbe`](#update-the-replicaset-pod-template-with-the-fixed-readinessprobe)
    - [Clean up the failing versions and the old ones](#clean-up-the-failing-versions-and-the-old-ones)

## Introduction

>>>
A ReplicaSet is defined with fields, including a selector that specifies how to identify Pods it can acquire, a number of replicas indicating how many Pods it should be maintaining, and a pod template specifying the data of new Pods it should create to meet the number of replicas criteria. A ReplicaSet then fulfills its purpose by creating and deleting Pods as needed to reach the desired number. When a ReplicaSet needs to create new Pods, it uses its Pod template.
>>>

### Learn more

- https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/

- https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#replicasetspec-v1-apps

### Some notes

- Kubernetes is fast, specially when working with lightweight containers, so to see what is happening, we'll need to run `kubectl` commands fast.

That's why we will run the `kubectl` command to apply changes and if works, immediately after, a `kubectl get` with the `-w, --watch` flag:

`-w, --watch=false: After listing/getting the requested object, watch for changes. Uninitialized objects are excluded if no object name is provided.`

This will allow us to get the information on what is happening just after the command is applied:

```
$ kubectl run --generator 'run-pod/v1' --image bash:5.0 --restart Never sleepy -
- sleep 10 && kubectl get pods sleepy -w
pod/sleepy created
NAME     READY   STATUS              RESTARTS   AGE
sleepy   0/1     ContainerCreating   0          0s
sleepy   1/1     Running             0          1s
sleepy   0/1     Completed           0          12s
```

This command creates a `Pod` called `sleepy` with a container using the image `bash:5.0` and running a `sleep 10`. Once the first command completes, the `kubectl get pods sleepy -w`, will `watch` a `Pod` called `sleepy` and print a new line for each change in the `Pod` status.

## 1 - Create a `ReplicaSet`

Create the `ReplicaSet` object:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: simple
spec:
  replicas: 1
  selector:
    matchLabels:
      app: simple
  template:
    metadata:
      labels:
        app: simple
    spec:
      containers:
      
      - name: app
        image: raelga/cats:gatet
```

Apply the `yaml`:

```
$ kubectl apply -f 101_simple-rs.yaml
replicaset.apps/simple created
```

```
$ kubectl get pods
NAME           READY   STATUS              RESTARTS   AGE
simple-hfsgg   0/1     ContainerCreating   0          3s
```

```
$ kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-hfsgg   1/1     Running   0          32s
```

```
$ kubectl get rs simple
NAME     DESIRED   CURRENT   READY   AGE
simple   1         1         1       29s
```

## 2 - Scaling `ReplicaSets`

### Double the numbers of replicas with `kubectl scale`

```
$ kubectl scale rs/simple --replicas 2
replicaset.extensions/simple scaled
```

```
$ k get rs simple
NAME     DESIRED   CURRENT   READY   AGE
simple   2         2         2       104s
```

```
$ kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-hfsgg   1/1     Running   0          74s
simple-kj8k8   1/1     Running   0          3s
```

### Scale back to 1 replica

```
$ kubectl scale rs/simple --replicas 1
replicaset.extensions/simple scaled
```

```
$ kubectl get pods
NAME           READY   STATUS        RESTARTS   AGE
simple-s8n2f   1/1     Terminating   0          48s
simple-hfsgg   1/1     Running       0          119s
```

```
$ kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-hfsgg   1/1     Running   0          125s
```

### Update the `ReplicaSet` with the yaml definition

We also add information about the resources needed by the app container of the pod, to let the scheduler know how many pods can fit into a node.

```diff
$ kubectl diff -f 201_simple-rs-5.yaml 
diff -u -N /tmp/LIVE-860683615/apps.v1.ReplicaSet.default.simple /tmp/MERGED-116908338/apps.v1.ReplicaSet.default.simple
--
- /tmp/LIVE-860683615/apps.v1.ReplicaSet.default.simple       2019-05-11 11:05:20.751504492 +0000
+++ /tmp/MERGED-116908338/apps.v1.ReplicaSet.default.simple     2019-05-11 11:05:20.767506423 +0000
@@ -5,14 +5,14 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"name":"simple","namespace":"default"},"spec":{"replicas":1,"selector":{"matchLabels":{"app":"simple"}},"template":{"metadata":{"labels":{"app":"simple"}},"spec":{"containers":[{"image":"raelga/cats:gatet","name":"app"}]}}}}
   creationTimestamp: "2019-05-11T11:01:50Z"

-  generation: 3
+  generation: 4
   name: simple
   namespace: default
   resourceVersion: "1560"
   selfLink: /apis/apps/v1/namespaces/default/replicasets/simple
   uid: 2db859ed-73dc-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 1
+  replicas: 5
   selector:
     matchLabels:
       app: simple
@@ -26,7 +26,13 @@
       
       - image: raelga/cats:gatet
         imagePullPolicy: IfNotPresent
         name: app

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

```
$ kubectl apply -f 201_simple-rs-5.yaml && kubectl get pods -w
replicaset.apps/simple configured
NAME           READY   STATUS              RESTARTS   AGE
simple-dgksp   0/1     ContainerCreating   0          0s
simple-hfsgg   1/1     Running             0          4m58s
simple-hm6gj   0/1     ContainerCreating   0          0s
simple-htdzs   0/1     ContainerCreating   0          0s
simple-rnbt6   0/1     ContainerCreating   0          0s
simple-htdzs   1/1     Running             0          2s
simple-hm6gj   1/1     Running             0          3s
simple-dgksp   1/1     Running             0          4s
simple-rnbt6   1/1     Running             0          4s
```

```
$ kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-dgksp   1/1     Running   0          10s
simple-hfsgg   1/1     Running   0          5m8s
simple-hm6gj   1/1     Running   0          10s
simple-htdzs   1/1     Running   0          10s
simple-rnbt6   1/1     Running   0          10s
```

### Scale to 50 replicas

```diff
$ kubectl diff -f 202_simple-rs-50.yaml
diff -u -N /tmp/LIVE-082216881/apps.v1.ReplicaSet.default.simple /tmp/MERGED-524798300/apps.v1.ReplicaSet.default.simple
--
- /tmp/LIVE-082216881/apps.v1.ReplicaSet.default.simple       2019-05-11 11:09:06.426174215 +0000
+++ /tmp/MERGED-524798300/apps.v1.ReplicaSet.default.simple     2019-05-11 11:09:06.440175724 +0000
@@ -5,14 +5,14 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"name":"simple","namespace":"default"},"spec":{"replicas":5,"selector":{"matchLabels":{"app":"simple"}},"template":{"metadata":{"labels":{"app":"simple"}},"spec":{"containers":[{"image":"raelga/cats:gatet","name":"app","resources":{"limits":{"cpu":"1","memory":"100Mi"},"requests":{"cpu":"50m","memory":"50Mi"}}}]}}}}
   creationTimestamp: "2019-05-11T11:01:50Z"

-  generation: 9
+  generation: 10
   name: simple
   namespace: default
   resourceVersion: "2292"
   selfLink: /apis/apps/v1/namespaces/default/replicasets/simple
   uid: 2db859ed-73dc-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 5
+  replicas: 50
   selector:
     matchLabels:
       app: simple
exit status 1
```

```
$ k apply -f 202_simple-rs-50.yaml && kubectl get rs simple -w
replicaset.apps/simple configured
NAME     DESIRED   CURRENT   READY   AGE
simple   50        5         5       12m
simple   50        5         5       12m
simple   50        50        5       12m
simple   50        50        6       12m
simple   50        50        7       12m
simple   50        50        8       12m
simple   50        50        9       12m
simple   50        50        10      12m
simple   50        50        11      12m
simple   50        50        12      12m
simple   50        50        13      12m
simple   50        50        14      12m
simple   50        50        15      12m
simple   50        50        16      12m
simple   50        50        17      12m
simple   50        50        18      12m
simple   50        50        19      13m
simple   50        50        20      13m
simple   50        50        21      13m
simple   50        50        22      13m
simple   50        50        23      13m
simple   50        50        24      13m
simple   50        50        25      13m
simple   50        50        26      13m
simple   50        50        27      13m
simple   50        50        28      13m
simple   50        50        29      13m
simple   50        50        30      13m
simple   50        50        31      13m
simple   50        50        32      13m
simple   50        50        33      13m
simple   50        50        34      13m
simple   50        50        35      13m
```

Check the pods that are not `Running`:

```
$ kubectl get pods --field-selector='status.phase!=Running'
NAME           READY   STATUS    RESTARTS   AGE
simple-7fbc4   0/1     Pending   0          39s
simple-9qsdq   0/1     Pending   0          39s
simple-b2xlw   0/1     Pending   0          39s
simple-bfdrl   0/1     Pending   0          39s
simple-dsnb7   0/1     Pending   0          39s
simple-f2jd6   0/1     Pending   0          38s
simple-gn48j   0/1     Pending   0          39s
simple-htlsv   0/1     Pending   0          39s
simple-qdhhh   0/1     Pending   0          39s
simple-rjvpm   0/1     Pending   0          39s
simple-rnbs8   0/1     Pending   0          39s
simple-s9msf   0/1     Pending   0          39s
simple-snkvj   0/1     Pending   0          38s
simple-th97b   0/1     Pending   0          39s
simple-tzz9n   0/1     Pending   0          39s
```

```
$ kubectl describe $(kubectl get pods --field-selector='status.phase!=Running' --output name | head -n1)
Name:               simple-7fbc4
Namespace:          default
Priority:           0
PriorityClassName:  <none>
Node:               <none>
Labels:             app=simple
Annotations:        <none>
Status:             Pending
IP:                 
Controlled By:      ReplicaSet/simple
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
  ---
  -     -----
  -            ---
  -               ---
  -               -------
  Warning  FailedScheduling  59s (x2 over 59s)  default-scheduler  0/2 nodes are available: 2 Insufficient cpu.
```

We can see that the *Pod* cannot be scheduled due to insufficient cpus in the node pool.

`Warning  FailedScheduling  41s (x6 over 3m58s)  default-scheduler  0/2 nodes are available: 2 Insufficient cpu.`

### Scale down back to 5 replicas

```
$ kubectl scale rs/simple --replicas 5 && kubectl get rs/simple -w
replicaset.extensions/simple scaled
NAME     DESIRED   CURRENT   READY   AGE
simple   5         50        35      34m
simple   5         50        35      34m
simple   5         5         5       34m
```

```
$ kubectl get pods  
NAME           READY   STATUS    RESTARTS   AGE
simple-hfsgg   1/1     Running   0          34m
simple-hzhpc   1/1     Running   0          22m
simple-wjdf9   1/1     Running   0          22m
simple-xgq2x   1/1     Running   0          22m
simple-xh5hm   1/1     Running   0          22m
```

## 3 - Selectors and Pods

### Deploy some **blue** pods

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: simple-blue-pod-1
  labels:
    app: simple
    color: blue
spec:
  containers:
    
    - name: app
      image: raelga/cats:liam
...
```

```
$ kubectl apply -f 301_simple-blue-pods.yaml && kubectl get pods -w
pod/simple-blue-pod-1 created
pod/simple-blue-pod-2 created
pod/simple-blue-pod-3 created
NAME                READY   STATUS        RESTARTS   AGE
simple-blue-pod-1   0/1     Terminating   0          1s
simple-blue-pod-2   0/1     Terminating   0          0s
simple-blue-pod-3   0/1     Terminating   0          0s
simple-hfsgg        1/1     Running       0          107m
simple-hzhpc        1/1     Running       0          95m
simple-wjdf9        1/1     Running       0          95m
simple-xgq2x        1/1     Running       0          95m
simple-xh5hm        1/1     Running       0          95m
simple-blue-pod-3   0/1     Terminating   0          2s
simple-blue-pod-3   0/1     Terminating   0          2s
simple-blue-pod-1   0/1     Terminating   0          5s
simple-blue-pod-1   0/1     Terminating   0          5s
simple-blue-pod-2   0/1     Terminating   0          11s
simple-blue-pod-2   0/1     Terminating   0          11s
```

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-hfsgg   1/1     Running   0          108m
simple-hzhpc   1/1     Running   0          96m
simple-wjdf9   1/1     Running   0          96m
simple-xgq2x   1/1     Running   0          96m
simple-xh5hm   1/1     Running   0          96m
```

The new *blue* pods get `Terminated`! Why??

```
$ k describe rs/simple
Name:         simple
Namespace:    default
Selector:     app=simple
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"name":"simple","namespace":"default"},"spec":{"replicas":50,"sel...
Replicas:     5 current / 5 desired
Pods Status:  5 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=simple
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
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: simple-blue-pod-1
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: simple-blue-pod-2
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: simple-blue-pod-3
```

We can see that the `ReplicaSet` terminated those *Pods*:

```
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: simple-blue-pod-1
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: simple-blue-pod-2
  Normal  SuccessfulDelete  71s   replicaset-controller  Deleted pod: simple-blue-pod-3
```

### Deploy a **blue** `ReplicaSet`

```
$ kubectl apply -f 302_simple-blue-rs.yaml && kubectl get pods -w
replicaset.apps/simple-blue created
NAME                READY   STATUS              RESTARTS   AGE
simple-blue-cff2b   0/1     Pending             0          0s
simple-blue-dp26t   0/1     Pending             0          0s
simple-blue-kfl7z   0/1     Pending             0          0s
simple-blue-kr46r   0/1     Pending             0          0s
simple-blue-nng6p   0/1     ContainerCreating   0          0s
simple-hfsgg        1/1     Running             0          112m
simple-hzhpc        1/1     Running             0          100m
simple-wjdf9        1/1     Running             0          100m
simple-xgq2x        1/1     Running             0          100m
simple-xh5hm        1/1     Running             0          100m
simple-blue-kfl7z   0/1     ContainerCreating   0          0s
simple-blue-dp26t   0/1     ContainerCreating   0          0s
simple-blue-cff2b   0/1     ContainerCreating   0          0s
simple-blue-kr46r   0/1     ContainerCreating   0          0s
simple-blue-cff2b   1/1     Running             0          2s
simple-blue-kfl7z   1/1     Running             0          3s
simple-blue-nng6p   1/1     Running             0          4s
simple-blue-kr46r   1/1     Running             0          4s
simple-blue-dp26t   1/1     Running             0          4s
```

```
$ kubectl get pods
NAME                READY   STATUS    RESTARTS   AGE
simple-blue-cff2b   1/1     Running   0          11s
simple-blue-dp26t   1/1     Running   0          11s
simple-blue-kfl7z   1/1     Running   0          11s
simple-blue-kr46r   1/1     Running   0          11s
simple-blue-nng6p   1/1     Running   0          11s
simple-hfsgg        1/1     Running   0          112m
simple-hzhpc        1/1     Running   0          100m
simple-wjdf9        1/1     Running   0          100m
simple-xgq2x        1/1     Running   0          100m
simple-xh5hm        1/1     Running   0          100m
```

```
$ kubectl get rs
NAME          DESIRED   CURRENT   READY   AGE
simple        5         5         5       112m
simple-blue   5         5         5       34s
```

Now the *Pods* stay, but why?

The selector is matching sets of pods, from most restrictive to less restrictive. So `rs/simple` with manage all pods with label: `app: simple` that doesn't match any other replicaset.

### Run a _red_ pod

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: simple-red-pod-1
  labels:
    app: simple
    color: red
spec:
  containers:
    
    - name: app
      image: raelga/cats:liam
```

This new *Pods*, have a color label. Will be deleted?

```
$ kubectl apply -f 303_simple-red-pods.yaml && kubectl get pods -w
pod/simple-red-pod-1 created
NAME                READY   STATUS        RESTARTS   AGE
simple-blue-cff2b   1/1     Running       0          75s
simple-blue-dp26t   1/1     Running       0          75s
simple-blue-kfl7z   1/1     Running       0          75s
simple-blue-kr46r   1/1     Running       0          75s
simple-blue-nng6p   1/1     Running       0          75s
simple-hfsgg        1/1     Running       0          113m
simple-hzhpc        1/1     Running       0          101m
simple-red-pod-1    0/1     Terminating   0          0s
simple-wjdf9        1/1     Running       0          101m
simple-xgq2x        1/1     Running       0          101m
simple-xh5hm        1/1     Running       0          101m
simple-red-pod-1    0/1     Terminating   0          7s
simple-red-pod-1    0/1     Terminating   0          7s
```

```
$ kubectl describe rs simple | grep simple-red-pod
  Normal  SuccessfulDelete  46s    replicaset-controller  Deleted pod: simple-red-pod-1
```

The **red** `Pod` is killed because:


- Has the `app: simple` label selector

- There is no any `ReplicaSet` for the `color: red` pods

This pods matches `simple` `ReplicaSet` selector and there is already 5 pods pods matching the selector, so should be terminated.

### `ReplicaSet` for non-colored pods only

The new selector for the `rs/simple-nocolor` will be a combination of a label and an expresion:

```yaml
  selector:
    matchLabels:
      app: simple
    matchExpressions:
      
      - { key: color, operator: DoesNotExist }
```

Let's try to update the `simple` `ReplicaSet`:

```diff
$ kubectl diff -f 304_simple-rs-nocolor-update.yaml 
The ReplicaSet "simple" is invalid: spec.selector: Invalid value: v1.LabelSelector{MatchLabels:map[string]string{"app":"simple"}, MatchExpressions:[]v1.LabelSelectorRequirement{v1.LabelSelectorRequirement{Key:"color", Operator:"DoesNotExist", Values:[]string(nil)}}}: field is immutable
```

``ReplicaSets` are defined by the `.spec.selectors` and are inmmutable.`

Let's create a new `ReplicaSet` then:

```
$ kubectl apply -f 305_simple-nocolor-rs.yaml
replicaset.apps/simple-nocolor created
```

```
$ kubectl get rs
NAME             DESIRED   CURRENT   READY   AGE
simple           5         5         5       121m
simple-blue      5         5         5       9m38s
simple-nocolor   5         5         5       16s
```

Let's create some orange `Pods`:

```
$ kubectl apply -f 306_simple-orange-pods.yaml && kubectl get pods -w -l color=orange
pod/simple-orange-pod-1 created
pod/simple-orange-pod-2 created
pod/simple-orange-pod-3 created
NAME                  READY   STATUS        RESTARTS   AGE
simple-orange-pod-1   0/1     Terminating   0          0s
simple-orange-pod-2   0/1     Terminating   0          0s
simple-orange-pod-3   0/1     Terminating   0          0s
```

They are still getting delted by the `rs/simple` controller.

```
$ kubectl describe rs simple | grep orange        
  Normal  SuccessfulDelete  33s (x3 over 89s)  replicaset-controller  Deleted pod: simple-orange-pod-1
  Normal  SuccessfulDelete  33s (x3 over 89s)  replicaset-controller  Deleted pod: simple-orange-pod-2
  Normal  SuccessfulDelete  33s (x3 over 89s)  replicaset-controller  Deleted pod: simple-orange-pod-3
```

Let's remove the `simple` `ReplicaSet` then:

```
$ kubectl delete rs/simple            
replicaset.extensions "simple" deleted
```

```
$ kubectl get rs          
NAME             DESIRED   CURRENT   READY   AGE
simple-blue      5         5         5       12m
simple-nocolor   5         5         5       3m32s
```

Let's create again the orange `Pods`.

```
$ kubectl apply -f 306_simple-orange-pods.yaml && kubectl get pods -w -l color=orange
pod/simple-orange-pod-1 created
pod/simple-orange-pod-2 created
pod/simple-orange-pod-3 created
NAME                  READY   STATUS              RESTARTS   AGE
simple-orange-pod-1   0/1     ContainerCreating   0          1s
simple-orange-pod-2   0/1     ContainerCreating   0          1s
simple-orange-pod-3   0/1     ContainerCreating   0          0s
simple-orange-pod-2   1/1     Running             0          3s
simple-orange-pod-3   1/1     Running             0          4s
simple-orange-pod-1   1/1     Running             0          7s
```

```
$ kubectl get pods
NAME                   READY   STATUS    RESTARTS   AGE
simple-blue-cff2b      1/1     Running   0          13m
simple-blue-dp26t      1/1     Running   0          13m
simple-blue-kfl7z      1/1     Running   0          13m
simple-blue-kr46r      1/1     Running   0          13m
simple-blue-nng6p      1/1     Running   0          13m
simple-nocolor-pcf6d   1/1     Running   0          3m58s
simple-nocolor-qfn9l   1/1     Running   0          3m58s
simple-nocolor-rlkdl   1/1     Running   0          3m58s
simple-nocolor-txglk   1/1     Running   0          3m58s
simple-nocolor-vmxm5   1/1     Running   0          3m58s
simple-orange-pod-1    1/1     Running   0          11s
simple-orange-pod-2    1/1     Running   0          11s
simple-orange-pod-3    1/1     Running   0          10s
```

### Let's acquire those fancy orange `pods`

```
kubectl apply -f 307_simple-orange-rs.yaml
replicaset.apps/simple-orange created
```

```
$ kubectl get pods -l color=orange
NAME                  READY   STATUS    RESTARTS   AGE
simple-orange-k72nq   1/1     Running   0          23s
simple-orange-mlh9h   1/1     Running   0          23s
simple-orange-pod-1   1/1     Running   0          2m14s
simple-orange-pod-2   1/1     Running   0          2m14s
simple-orange-pod-3   1/1     Running   0          2m13s
simple-orange-vkclj   1/1     Running   0          23s
```

As you can see, the `ReplicaSet` only created the required pods to have 6 replicas:

```
$ kubectl describe rs simple-orange | grep SuccessfulCreate
  Normal  SuccessfulCreate  67s   replicaset-controller  Created pod: simple-orange-mlh9h
  Normal  SuccessfulCreate  67s   replicaset-controller  Created pod: simple-orange-k72nq
  Normal  SuccessfulCreate  67s   replicaset-controller  Created pod: simple-orange-vkclj
```

### Remove a pod from the orange replicaset

```
$ kubectl patch pod simple-orange-pod-1 --type='json' --patch='[{"op":"replace", "path":"/metadata/labels/color", "value":"pink"}]' && kubectl get pods -w -l color=orange
pod/simple-orange-pod-1 patched
NAME                  READY   STATUS              RESTARTS   AGE
simple-orange-5s295   1/1     Running             0          4m2s
simple-orange-6nd67   0/1     ContainerCreating   0          0s
simple-orange-gzwjs   1/1     Running             0          4m3s
simple-orange-pod-2   1/1     Running             0          4m6s
simple-orange-pod-3   1/1     Running             0          4m6s
simple-orange-v9lsm   1/1     Running             0          4m2s
simple-orange-6nd67   1/1     Running             0          2s
```

The `simple-orange-pod-1` is no longer part of the `ReplicaSet` and the `simple-orange-6nd67` has been created to ensure that there are 6 replicas running.

```
$ kubectl patch pod simple-orange-pod-2 --type='json' --patch='[{"op":"replace", "path":"/metadata/labels/color", "value":"pink"}]' && kubectl get rs simple-orange -w
pod/simple-orange-pod-2 patched
NAME            DESIRED   CURRENT   READY   AGE
simple-orange   6         6         5       8m13s
simple-orange   6         6         6       8m15s
```

```
$ kubectl get pods -l color=pink
NAME                  READY   STATUS    RESTARTS   AGE
simple-orange-pod-1   1/1     Running   0          9m21s
simple-orange-pod-2   1/1     Running   0          9m21s
```

### Clean up

```
$ kubectl delete rs simple-blue simple-nocolor simple-orange
replicaset.extensions "simple-blue" deleted
replicaset.extensions "simple-nocolor" deleted
replicaset.extensions "simple-orange" deleted
```

```
$ kubectl get pods
NAME                  READY   STATUS    RESTARTS   AGE
simple-orange-pod-1   1/1     Running   0          9m50s
simple-orange-pod-2   1/1     Running   0          9m50s
```

```
$ kubectl delete pods -l color=pink 
pod "simple-orange-pod-1" deleted
pod "simple-orange-pod-2" deleted
```

```
$ kubectl get pods
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
      
      - name: app
        image: raelga/cats:neu
        readinessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          successThreshold: 3
```

```
$ kubectl apply -f 400_probes-rs-readiness.yaml && kubectl get pods -w -l app=probes
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

```
$ kubectl apply -f 401_probes-rs-readiness-ko.yaml && kubectl get pods -l app=probes -w
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
$ kubectl get pods -l app=probes
NAME           READY   STATUS    RESTARTS   AGE
probes-csqfn   0/1     Running   0          86s
probes-m2l5h   1/1     Running   0          2m17s
probes-np7vg   0/1     Running   0          86s
probes-x56j5   1/1     Running   0          2m17s
```

And if we look the status of the `READY 0/1` pods, we'll see the reason in the `Events:` section:

```
$ kubectl describe pods $(kubectl get pods | sed -n 's:\(\S\+\)\s\+0/1.*:\1:p') | grep Warning
  Warning  Unhealthy  2s (x17 over 82s)  kubelet, cnbcn-k8s-study-jam-np-fw7y  Readiness probe failed: dial tcp 10.244.1.225:81: connect: connection refused
  Warning  Unhealthy  0s (x17 over 80s)  kubelet, cnbcn-k8s-study-jam-np-fw7x  Readiness probe failed: dial tcp 10.244.0.55:81: connect: connection refused
```

```
$ kubectl describe pods $(kubectl get pods | sed -n 's:\(\S\+\)\s\+0/1.*:\1:p')
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
      
      - name: app
        image: raelga/cats:neu
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 2
```

```
$ kubectl apply -f 402_probes-rs-liveness.yaml && kubectl get pods -l app=probes -w
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

```
$ kubectl apply -f 403_probes-rs-liveness-ko.yaml && kubectl get pods -l app=probes -w
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

### Clean up

```
$ kubectl delete rs probes && kubectl get pods -w -l app=probes
replicaset.extensions "probes" deleted
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
$ kubectl get pods
No resources found.
```

## 5 - Manual rolling update

### Deploy the initial `ReplicaSet`

```
$ kubectl apply -f 501_probes-images-rs.yaml && kubectl get pods -l app=probes-images -w
replicaset.apps/probes-images created
NAME                  READY   STATUS    RESTARTS   AGE
probes-images-dtfv4   0/1     Pending   0          0s
probes-images-jnck4   0/1     Pending   0          0s
probes-images-dtfv4   0/1     Pending   0          0s
probes-images-h5wsz   0/1     Pending   0          0s
probes-images-h5wsz   0/1     Pending   0          0s
probes-images-jnck4   0/1     Pending   0          0s
probes-images-dtfv4   0/1     ContainerCreating   0          0s
probes-images-jnck4   0/1     ContainerCreating   0          0s
probes-images-h5wsz   0/1     ContainerCreating   0          0s
probes-images-h5wsz   0/1     Running             0          2s
probes-images-jnck4   0/1     Running             0          3s
probes-images-dtfv4   0/1     Running             0          3s
probes-images-h5wsz   1/1     Running             0          7s
probes-images-jnck4   1/1     Running             0          7s
probes-images-dtfv4   1/1     Running             0          10s
```

Let's list the pods running, including the name of the first container image, using `custom-columns` output format: 

`-o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime`

```
$ kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime
NAME                  IMAGE             STATUS    STARTED
probes-images-dtfv4   raelga/cats:neu   Running   2019-05-11T16:20:36Z
probes-images-h5wsz   raelga/cats:neu   Running   2019-05-11T16:20:36Z
probes-images-jnck4   raelga/cats:neu   Running   2019-05-11T16:20:36Z
```

### Update the `ReplicaSet` pod template

Let's update the `ReplicaSet` `Pod` template and include a new template, that will fail the `ReadinessProbe`.

```diff
$ kubectl diff -f 502_probes-images-rs-update-image-ko.yaml 
diff -u -N /tmp/LIVE-839052409/apps.v1.ReplicaSet.default.probes-images /tmp/MERGED-353118084/apps.v1.ReplicaSet.default.probes-images
--
- /tmp/LIVE-839052409/apps.v1.ReplicaSet.default.probes-images        2019-05-11 16:21:15.916702182 +0000
+++ /tmp/MERGED-353118084/apps.v1.ReplicaSet.default.probes-images      2019-05-11 16:21:15.929703344 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"probes-images"},"name":"probes-images","namespace":"default"},"spec":{"replicas":3,"selector":{"matchLabels":{"app":"probes-images"}},"template":{"metadata":{"labels":{"app":"probes-images"}},"spec":{"containers":[{"image":"raelga/cats:neu","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"app","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 1
+  generation: 2
   labels:
     app: probes-images
   name: probes-images
@@ -25,7 +25,7 @@
         app: probes-images
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

```
$ kubectl apply -f 502_probes-images-rs-update-image-ko.yaml && kubectl get pods -l app=probes-images -w
replicaset.apps/probes-images configured
NAME                  READY   STATUS    RESTARTS   AGE
probes-images-dtfv4   1/1     Running   0          56s
probes-images-h5wsz   1/1     Running   0          56s
probes-images-jnck4   1/1     Running   0          56s
```

Nothing happens, as the `ReplicaSet` only cares for the number of replicas, the new `Pod` template will be used for creating new `Pods` when required, but has no effect on the existing `ReplicaSet` `Pods`.

```
$ kubectl get rs probes-images
NAME            DESIRED   CURRENT   READY   AGE
probes-images   3         3         3       20m
```

Let's increase the number of replicas to 6:

```diff
$ kubectl diff -f 503_probes-images-rs-6-update-image-ko.yaml 
diff -u -N /tmp/LIVE-648056706/apps.v1.ReplicaSet.default.probes-images /tmp/MERGED-796264697/apps.v1.ReplicaSet.default.probes-images
--
- /tmp/LIVE-648056706/apps.v1.ReplicaSet.default.probes-images        2019-05-11 16:23:07.606688192 +0000
+++ /tmp/MERGED-796264697/apps.v1.ReplicaSet.default.probes-images      2019-05-11 16:23:07.619689354 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"probes-images"},"name":"probes-images","namespace":"default"},"spec":{"replicas":3,"selector":{"matchLabels":{"app":"probes-images"}},"template":{"metadata":{"labels":{"app":"probes-images"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"app","readinessProbe":{"httpGet":{"path":"/bad-endpoint","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 2
+  generation: 3
   labels:
     app: probes-images
   name: probes-images
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/probes-images
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 3
+  replicas: 6
   selector:
     matchLabels:
       app: probes-images
exit status 1
```

Now the start but never get `READY`, as they are not passing the `ReadinessProbe`:

```
$ kubectl apply -f 503_probes-images-rs-6-update-image-ko.yaml && kubectl get pods -l app=probes-images -w
replicaset.apps/probes-images configured
NAME                  READY   STATUS              RESTARTS   AGE
probes-images-42vbb   0/1     ContainerCreating   0          0s
probes-images-dhs88   0/1     ContainerCreating   0          0s
probes-images-dtfv4   1/1     Running             0          3m21s
probes-images-fhrlp   0/1     ContainerCreating   0          0s
probes-images-h5wsz   1/1     Running             0          3m21s
probes-images-jnck4   1/1     Running             0          3m21s
probes-images-dhs88   0/1     Running             0          2s
probes-images-42vbb   0/1     Running             0          2s
probes-images-fhrlp   0/1     Running             0          2s
```

At this point, the old image is still running and serving requests. The new version is failing, but never gets traffic, as is not passing the `ReadinessProbe`.

```
$ kubectl get rs probes-images
NAME            DESIRED   CURRENT   READY   AGE
probes-images   6         6         3       4m25s
```

```
$ kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime
NAME                  IMAGE                STATUS    STARTED
probes-images-42vbb   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
probes-images-dhs88   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
probes-images-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-fhrlp   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
probes-images-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
```

We can see the `ReadinessProbe` error using `kubectl describe`:

```
$ kubectl describe pods -l app=probes-images | grep Warning
  Warning  Unhealthy  9s (x19 over 3m9s)  kubelet, cnbcn-k8s-study-jam-np-fw7x  Readiness probe failed: HTTP probe failed with statuscode: 404
  Warning  Unhealthy  3s (x19 over 3m3s)  kubelet, cnbcn-k8s-study-jam-np-fw7y  Readiness probe failed: HTTP probe failed with statuscode: 404
  Warning  Unhealthy  1s (x20 over 3m11s)  kubelet, cnbcn-k8s-study-jam-np-fw7x  Readiness probe failed: HTTP probe failed with statuscode: 404
```

### Update the `ReplicaSet` `Pod` template with the fixed `ReadinessProbe`

```diff
$ kubectl diff -f 504_probes-images-rs-9-update-image-ok.yaml 
diff -u -N /tmp/LIVE-210527442/apps.v1.ReplicaSet.default.probes-images /tmp/MERGED-362151945/apps.v1.ReplicaSet.default.probes-images
--
- /tmp/LIVE-210527442/apps.v1.ReplicaSet.default.probes-images        2019-05-11 16:30:04.733986406 +0000
+++ /tmp/MERGED-362151945/apps.v1.ReplicaSet.default.probes-images      2019-05-11 16:30:04.746987569 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"probes-images"},"name":"probes-images","namespace":"default"},"spec":{"replicas":6,"selector":{"matchLabels":{"app":"probes-images"}},"template":{"metadata":{"labels":{"app":"probes-images"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"app","readinessProbe":{"httpGet":{"path":"/bad-endpoint","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 3
+  generation: 4
   labels:
     app: probes-images
   name: probes-images
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/probes-images
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 6
+  replicas: 9
   selector:
     matchLabels:
       app: probes-images
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

```
$ kubectl apply -f 504_probes-images-rs-9-update-image-ok.yaml && kubectl get rs probes-images -w
replicaset.apps/probes-images configured
NAME            DESIRED   CURRENT   READY   AGE
probes-images   9         9         3       11m
probes-images   9         9         4       11m
probes-images   9         9         5       11m
probes-images   9         9         6       11m
```

The `ReplicaSet` now has 9 replicas, 6 of them with the new image:

```
$ kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime
NAME                  IMAGE                STATUS    STARTED
probes-images-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-dhs88   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
probes-images-fhrlp   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
probes-images-42vbb   raelga/cats:blanca   Running   2019-05-11T16:23:57Z
probes-images-7g9cc   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
probes-images-r87pj   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
probes-images-ssxzx   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
```

And the last 3 replicas, with the fixed `ReadinessProbe`, are `READY`:

```
$ kubectl get pods --sort-by=.status.startTime
NAME                  READY   STATUS    RESTARTS   AGE
probes-images-jnck4   1/1     Running   0          12m
probes-images-dtfv4   1/1     Running   0          12m
probes-images-h5wsz   1/1     Running   0          12m
probes-images-dhs88   0/1     Running   0          9m7s
probes-images-fhrlp   0/1     Running   0          9m7s
probes-images-42vbb   0/1     Running   0          9m7s
probes-images-7g9cc   1/1     Running   0          60s
probes-images-r87pj   1/1     Running   0          60s
probes-images-ssxzx   1/1     Running   0          60s
```

The new `ReplicaSet` template is creating healthy `Pods`!

### Clean up the failing versions and the old ones

Now, let's clean up the failing `Pods` by scaling back to 6!

```
$ kubectl scale rs/probes-images --replicas 6
replicaset.extensions/probes-images scaled
```

```
$ kubectl get pods
NAME                  READY   STATUS        RESTARTS   AGE
probes-images-42vbb   0/1     Terminating   0          13m
probes-images-7g9cc   1/1     Running       0          5m27s
probes-images-dhs88   0/1     Terminating   0          13m
probes-images-dtfv4   1/1     Running       0          16m
probes-images-fhrlp   0/1     Terminating   0          13m
probes-images-h5wsz   1/1     Running       0          16m
probes-images-jnck4   1/1     Running       0          16m
probes-images-r87pj   1/1     Running       0          5m27s
probes-images-ssxzx   1/1     Running       0          5m27s
```

```
$ kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime
NAME                  IMAGE                STATUS    STARTED
probes-images-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-7g9cc   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
probes-images-r87pj   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
probes-images-ssxzx   raelga/cats:blanca   Running   2019-05-11T16:32:04Z
```

Let's now clean the old version by scaling back to 3!

```
$ kubectl scale rs/probes-images --replicas 3    
replicaset.extensions/probes-images scaled
```

```
$ kubectl get pods
NAME                  READY   STATUS        RESTARTS   AGE
probes-images-dtfv4   1/1     Running       0          20m
probes-images-h5wsz   1/1     Running       0          20m
probes-images-jnck4   1/1     Running       0          20m
probes-images-r87pj   0/1     Terminating   0          9m13s
probes-images-ssxzx   0/1     Terminating   0          9m13s
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
diff -u -N /tmp/LIVE-571681951/apps.v1.ReplicaSet.default.probes-images /tmp/MERGED-052727154/apps.v1.ReplicaSet.default.probes-images
--
- /tmp/LIVE-571681951/apps.v1.ReplicaSet.default.probes-images        2019-05-11 16:58:39.800320854 +0000
+++ /tmp/MERGED-052727154/apps.v1.ReplicaSet.default.probes-images      2019-05-11 16:58:39.823322911 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"probes-images"},"name":"probes-images","namespace":"default"},"spec":{"replicas":6,"selector":{"matchLabels":{"app":"probes-images"}},"template":{"metadata":{"labels":{"app":"probes-images"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"app","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 20
+  generation: 21
   labels:
     app: probes-images
   name: probes-images
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/probes-images
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 3
+  replicas: 6
   selector:
     matchLabels:
       app: probes-images
@@ -23,6 +23,7 @@
       creationTimestamp: null
       labels:
         app: probes-images
+        version: v2.0
     spec:
       containers:
       
       - image: raelga/cats:blanca
exit status 1
```

```
$ kubectl apply -f 505_probes-images-rs-6-update-image-ok.yaml && kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime -w
replicaset.apps/probes-images configured
NAME                  IMAGE                STATUS    STARTED
probes-images-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-pbltv   raelga/cats:blanca   Pending   2019-05-11T17:00:12Z
probes-images-sv698   raelga/cats:blanca   Pending   2019-05-11T17:00:12Z
probes-images-vbrqc   raelga/cats:blanca   Pending   2019-05-11T17:00:12Z
probes-images-pbltv   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-sv698   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-vbrqc   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-sv698   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-pbltv   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-vbrqc   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
```

```
$ kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime
NAME                  IMAGE                STATUS    STARTED
probes-images-dtfv4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-h5wsz   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-jnck4   raelga/cats:neu      Running   2019-05-11T16:20:36Z
probes-images-pbltv   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-sv698   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-vbrqc   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
```

As we added a new label to the template, is easy to identify the new replicas:

```
$ kubectl get pods -l app=probes-images,version=v2.0  
NAME                  READY   STATUS    RESTARTS   AGE
probes-images-pbltv   1/1     Running   0          55s
probes-images-sv698   1/1     Running   0          55s
probes-images-vbrqc   1/1     Running   0          55s
```

And now, we can remove the old version and the `ReplicaSet` will replace the terminated `pods` with new ones, using the `ReplicaSet` template:

```
$ kubectl get pods -l app=probes-images,version!=v2.0
NAME                  READY   STATUS    RESTARTS   AGE
probes-images-dtfv4   1/1     Running   0          41m
probes-images-h5wsz   1/1     Running   0          41m
probes-images-jnck4   1/1     Running   0          41m
```

```
$ kubectl delete  pods -l app=probes-images,version!=v2.0
pod "probes-images-dtfv4" deleted
pod "probes-images-h5wsz" deleted
pod "probes-images-jnck4" deleted
```

```
$  kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,STARTED:.status.startTime --sort-by=.status.startTime   
NAME                  IMAGE                STATUS    STARTED
probes-images-pbltv   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-sv698   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-vbrqc   raelga/cats:blanca   Running   2019-05-11T17:00:12Z
probes-images-62v48   raelga/cats:blanca   Running   2019-05-11T17:02:53Z
probes-images-bs6z9   raelga/cats:blanca   Running   2019-05-11T17:02:53Z
probes-images-ndhd7   raelga/cats:blanca   Running   2019-05-11T17:02:53Z
```

```
$ kubectl get pods -l app=probes-images,version!=v2.0
No resources found.
```

That worked! The problem, is that now the `ReplicaSet` selector is not the same as the labels defined in the `Pod` template, so another if another `ReplicaSet` is created with the exact match, this `ReplicaSet` will lose the `Pods`.

So let's update the `ReplicaSet` with the new selector!

```diff
$ diff -U5 505_probes-images-rs-6-update-image-ok.yaml 506_probes-images-rs-update-selector.yaml 
--
- 505_probes-images-rs-6-update-image-ok.yaml 2019-05-11 16:58:45.738851782 +0000
+++ 506_probes-images-rs-update-selector.yaml   2019-05-11 17:09:35.580954662 +0000
@@ -7,10 +7,11 @@
 spec:
   replicas: 6
   selector:
     matchLabels:
       app: probes-images
+      version: v2.0
   template:
     metadata:
       labels:
         app: probes-images
         version: v2.0
```

```
$ kubectl apply -f 506_probes-images-rs-update-selector.yaml
The ReplicaSet "probes-images" is invalid: spec.selector: Invalid value: v1.LabelSelector{MatchLabels:map[string]string{"app":"probes-images", "version":"v2.0"}, MatchExpressions:[]v1.LabelSelectorRequirement(nil)}: field is immutable
```

As we already saw before, the `ReplicaSet` selector field is `immutable`, so we need to create a new `ReplicaSet`.

```diff
$ diff -U5 505_probes-images-rs-6-update-image-ok.yaml 507_probes-images-v2.0-rs.yaml 
--
- 505_probes-images-rs-6-update-image-ok.yaml 2019-05-11 16:58:45.738851782 +0000
+++ 507_probes-images-v2.0-rs.yaml      2019-05-11 17:09:20.425599538 +0000
@@ -1,16 +1,17 @@
 apiVersion: apps/v1
 kind: ReplicaSet
 metadata:

-  name: probes-images
+  name: probes-images-v2.0
   labels:
     app: probes-images
 spec:
   replicas: 6
   selector:
     matchLabels:
       app: probes-images
+      version: v2.0
   template:
     metadata:
       labels:
         app: probes-images
         version: v2.0
```

Let's check the current status:

```
$ kubectl get rs -l app=probes-images
NAME            DESIRED   CURRENT   READY   AGE
probes-images   6         6         6       52m
```

Let's add the new `ReplicaSet`!

```
$ kubectl apply -f 507_probes-images-v2.0-rs.yaml && kubectl get rs -l app=probes-images -w
replicaset.apps/probes-images-v2.0 unchanged
NAME                 DESIRED   CURRENT   READY   AGE
probes-images        6         6         6       53m
probes-images-v2.0   6         6         2       10s
probes-images-v2.0   6         6         3       10s
probes-images-v2.0   6         6         4       11s
probes-images-v2.0   6         6         5       13s
probes-images-v2.0   6         6         6       14s
```

We changed the `ReplicaSet`, so new replicas have been created with the new `ReplicaSet` name prefix but leave the olds as were generated by another `ReplicaSet`. The ownership information is stored in the `.metadata.ownerReferences` array:

```
$  kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels,OWNER-TYPE:.metadata.ownerReferences[0].kind,OWNER-NAME:.metadata.ownerReferences[0].name --sort-by=.status.startTime
NAME                       LABELS                                OWNER-TYPE   OWNER-NAME
probes-images-pbltv        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-sv698        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-vbrqc        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-62v48        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-bs6z9        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-ndhd7        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-v2.0-9kpln   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-v2.0-dnl2k   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-v2.0-dxj4v   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-v2.0-hg8xb   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-v2.0-mmvzr   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-v2.0-86shb   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
```

We can see, that all the pods have the same `labels`, but are managed by different `ReplicaSets` and they will manage differnt set of `pods` with the same `labels`:

Let's scale down both `ReplicaSets` and see what happens:

```diff
$ kubectl diff -f 508_probes-images-scale-down-both-rs.yaml 
diff -u -N /tmp/LIVE-427424072/apps.v1.ReplicaSet.default.probes-images /tmp/MERGED-238269447/apps.v1.ReplicaSet.default.probes-images
--
- /tmp/LIVE-427424072/apps.v1.ReplicaSet.default.probes-images        2019-05-11 17:41:33.346631258 +0000
+++ /tmp/MERGED-238269447/apps.v1.ReplicaSet.default.probes-images      2019-05-11 17:41:33.360632510 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"probes-images"},"name":"probes-images","namespace":"default"},"spec":{"replicas":6,"selector":{"matchLabels":{"app":"probes-images"}},"template":{"metadata":{"labels":{"app":"probes-images","version":"v2.0"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"app","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 23
+  generation: 24
   labels:
     app: probes-images
   name: probes-images
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/probes-images
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 6
+  replicas: 2
   selector:
     matchLabels:
       app: probes-images
diff -u -N /tmp/LIVE-427424072/apps.v1.ReplicaSet.default.probes-images-v2.0 /tmp/MERGED-238269447/apps.v1.ReplicaSet.default.probes-images-v2.0
--
- /tmp/LIVE-427424072/apps.v1.ReplicaSet.default.probes-images-v2.0   2019-05-11 17:41:33.486643786 +0000
+++ /tmp/MERGED-238269447/apps.v1.ReplicaSet.default.probes-images-v2.0 2019-05-11 17:41:33.500645039 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"probes-images"},"name":"probes-images-v2.0","namespace":"default"},"spec":{"replicas":6,"selector":{"matchLabels":{"app":"probes-images","version":"v2.0"}},"template":{"metadata":{"labels":{"app":"probes-images","version":"v2.0"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"app","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T17:13:37Z"

-  generation: 1
+  generation: 2
   labels:
     app: probes-images
   name: probes-images-v2.0
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/probes-images-v2.0
   uid: 1d717f4e-7410-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 6
+  replicas: 2
   selector:
     matchLabels:
       app: probes-images
exit status 1
```

```
$ kubectl apply -f 508_probes-images-scale-down-both-rs.yaml && kubectl get pods -w -l app=probes-images
replicaset.apps/probes-images configured
replicaset.apps/probes-images-v2.0 configured
NAME                       READY   STATUS        RESTARTS   AGE
probes-images-62v48        1/1     Terminating   0          39m
probes-images-bs6z9        1/1     Terminating   0          39m
probes-images-ndhd7        1/1     Terminating   0          39m
probes-images-pbltv        1/1     Running       0          42m
probes-images-sv698        1/1     Running       0          42m
probes-images-v2.0-86shb   1/1     Running       0          28m
probes-images-v2.0-9kpln   1/1     Running       0          28m
probes-images-v2.0-dnl2k   1/1     Terminating   0          28m
probes-images-v2.0-dxj4v   1/1     Terminating   0          28m
probes-images-v2.0-hg8xb   1/1     Terminating   0          28m
probes-images-v2.0-mmvzr   1/1     Terminating   0          28m
probes-images-vbrqc        1/1     Terminating   0          42m
probes-images-v2.0-mmvzr   0/1     Terminating   0          28m
probes-images-62v48        0/1     Terminating   0          39m
probes-images-vbrqc        0/1     Terminating   0          42m
probes-images-bs6z9        0/1     Terminating   0          39m
probes-images-62v48        0/1     Terminating   0          39m
probes-images-v2.0-dnl2k   0/1     Terminating   0          28m
probes-images-v2.0-dnl2k   0/1     Terminating   0          28m
probes-images-vbrqc        0/1     Terminating   0          42m
probes-images-vbrqc        0/1     Terminating   0          42m
probes-images-vbrqc        0/1     Terminating   0          42m
probes-images-ndhd7        0/1     Terminating   0          39m
probes-images-ndhd7        0/1     Terminating   0          39m
probes-images-62v48        0/1     Terminating   0          39m
probes-images-v2.0-dxj4v   0/1     Terminating   0          28m
probes-images-62v48        0/1     Terminating   0          39m
probes-images-v2.0-hg8xb   0/1     Terminating   0          28m
probes-images-bs6z9        0/1     Terminating   0          39m
probes-images-bs6z9        0/1     Terminating   0          39m
probes-images-v2.0-mmvzr   0/1     Terminating   0          28m
probes-images-v2.0-mmvzr   0/1     Terminating   0          28m
probes-images-v2.0-hg8xb   0/1     Terminating   0          28m
probes-images-v2.0-hg8xb   0/1     Terminating   0          28m
```

```
$ kubectl get pods -l app=probes-images 
NAME                       READY   STATUS    RESTARTS   AGE
probes-images-pbltv        1/1     Running   0          42m
probes-images-sv698        1/1     Running   0          42m
probes-images-v2.0-86shb   1/1     Running   0          29m
probes-images-v2.0-9kpln   1/1     Running   0          29m
```

```
$  kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels,OWNER-TYPE:.metadata.ownerReferences[0].kind,OWNER-NAME:.metadata.ownerReferences[0].name --sort-by=.status.startTime
NAME                       LABELS                                OWNER-TYPE   OWNER-NAME
probes-images-pbltv        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-sv698        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-v2.0-86shb   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-v2.0-9kpln   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
```

And now scale both up!

```diff
$ kubectl diff -f 509_probes-images-scale-up-both-rs.yaml   
diff -u -N /tmp/LIVE-749110581/apps.v1.ReplicaSet.default.probes-images /tmp/MERGED-606903056/apps.v1.ReplicaSet.default.probes-images
--
- /tmp/LIVE-749110581/apps.v1.ReplicaSet.default.probes-images        2019-05-11 17:43:39.257897487 +0000
+++ /tmp/MERGED-606903056/apps.v1.ReplicaSet.default.probes-images      2019-05-11 17:43:39.278899367 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"probes-images"},"name":"probes-images","namespace":"default"},"spec":{"replicas":2,"selector":{"matchLabels":{"app":"probes-images"}},"template":{"metadata":{"labels":{"app":"probes-images","version":"v2.0"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"app","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T16:20:36Z"

-  generation: 24
+  generation: 25
   labels:
     app: probes-images
   name: probes-images
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/probes-images
   uid: b57546b3-7408-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 2
+  replicas: 4
   selector:
     matchLabels:
       app: probes-images
diff -u -N /tmp/LIVE-749110581/apps.v1.ReplicaSet.default.probes-images-v2.0 /tmp/MERGED-606903056/apps.v1.ReplicaSet.default.probes-images-v2.0
--
- /tmp/LIVE-749110581/apps.v1.ReplicaSet.default.probes-images-v2.0   2019-05-11 17:43:39.420912073 +0000
+++ /tmp/MERGED-606903056/apps.v1.ReplicaSet.default.probes-images-v2.0 2019-05-11 17:43:39.440913863 +0000
@@ -5,7 +5,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"labels":{"app":"probes-images"},"name":"probes-images-v2.0","namespace":"default"},"spec":{"replicas":2,"selector":{"matchLabels":{"app":"probes-images","version":"v2.0"}},"template":{"metadata":{"labels":{"app":"probes-images","version":"v2.0"}},"spec":{"containers":[{"image":"raelga/cats:blanca","livenessProbe":{"failureThreshold":2,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":5},"name":"app","readinessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":2}}]}}}}
   creationTimestamp: "2019-05-11T17:13:37Z"

-  generation: 2
+  generation: 3
   labels:
     app: probes-images
   name: probes-images-v2.0
@@ -14,7 +14,7 @@
   selfLink: /apis/apps/v1/namespaces/default/replicasets/probes-images-v2.0
   uid: 1d717f4e-7410-11e9-9a36-eefc5b75fd0d
 spec:

-  replicas: 2
+  replicas: 4
   selector:
     matchLabels:
       app: probes-images
exit status 1
```

```
$ kubectl apply -f 509_probes-images-scale-up-both-rs.yaml && kubectl get rs -l app=probes-images -w 
replicaset.apps/probes-images configured
replicaset.apps/probes-images-v2.0 configured
NAME                 DESIRED   CURRENT   READY   AGE
probes-images        4         4         2       83m
probes-images-v2.0   4         4         2       30m
probes-images        4         4         3       83m
probes-images        4         4         4       83m
probes-images-v2.0   4         4         3       30m
probes-images-v2.0   4         4         4       30m
```

```
$  kubectl get pods -l app=probes-images -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels,OWNER-TYPE:.metadata.ownerReferences[0].kind,OWNER-NAME:.metadata.ownerReferences[0].name --sort-by=.status.startTime
NAME                       LABELS                                OWNER-TYPE   OWNER-NAME
probes-images-pbltv        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-sv698        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-v2.0-86shb   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-v2.0-9kpln   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-7qtn8        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
probes-images-v2.0-n49jk   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-v2.0-szbh4   map[app:probes-images version:v2.0]   ReplicaSet   probes-images-v2.0
probes-images-zmdfk        map[app:probes-images version:v2.0]   ReplicaSet   probes-images
```

It has become clear clear that `ReplicaSet` is not meant to be used for `Rolling Updates` or deploying new versions of our application. Is for keeping a number of replicas of a `Pod` running and that's all.

For manage application *deployments*, we need another kind of Kubernetes object that should work with `ReplicaSets`... Lucky for us, Kubernetes has an object for that called... you guessed... `Deployments`.