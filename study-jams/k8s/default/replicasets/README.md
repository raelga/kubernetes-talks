## ReplicaSets

## Create a simple replicaset with 1 pod

```
$ kubectl apply -f 00_simple-rs.yaml
replicaset.apps/simple created
```

```
$ kubectl get rs
NAME     DESIRED   CURRENT   READY   AGE
simple   1         1         1       7s
```

```
$ kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-s8n2f   1/1     Running   0          8s
```

## Scaling ReplicaSets

### Double the numbers of replicas with scale

```
$ kubectl scale rs/simple --replicas 2
replicaset.extensions/simple scaled
```

```
$ kubectl get pods
NAME           READY   STATUS              RESTARTS   AGE
simple-bs87n   0/1     ContainerCreating   0          1s
simple-s8n2f   1/1     Running             0          4m17s
```

```
$ kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-s8n2f   1/1     Running   0          113s
simple-t4ldv   1/1     Running   0          3s
```

## Scale back to 1 replica

```
$ kubectl scale rs/simple --replicas 1
replicaset.extensions/simple scaled
```

```
$ kubectl get pods
NAME           READY   STATUS        RESTARTS   AGE
simple-bpq7w   1/1     Terminating   0          30s
simple-s8n2f   1/1     Running       0          3m15s
```

```
$ kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-s8n2f   1/1     Running   0          3m28s
```

### Update the replica count with the yaml definition

```
$ k diff -f 01_simple-rs-updated.yaml
diff -u -N /tmp/LIVE-132357089/apps.v1.ReplicaSet.default.simple /tmp/MERGED-724057548/apps.v1.ReplicaSet.default.simple
--- /tmp/LIVE-132357089/apps.v1.ReplicaSet.default.simple       2019-05-09 16:00:06.496205700 +0200
+++ /tmp/MERGED-724057548/apps.v1.ReplicaSet.default.simple     2019-05-09 16:00:06.596947400 +0200
@@ -5,14 +5,14 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"ReplicaSet","metadata":{"annotations":{},"name":"simple","namespace":"default"},"spec":{"replicas":1,"selector":{"matchLabels":{"app":"simple"}},"template":{"metadata":{"labels":{"app":"simple"}},"spec":{"containers":[{"image":"raelga/cats:gatet","name":"app"}]}}}}
   creationTimestamp: "2019-05-09T13:53:29Z"
-  generation: 11
+  generation: 12
   name: simple
   namespace: default
   resourceVersion: "87268"
   selfLink: /apis/apps/v1/namespaces/default/replicasets/simple
   uid: d321dab8-7261-11e9-958d-2ad697fba57a
 spec:
-  replicas: 1
+  replicas: 5
   selector:
     matchLabels:
       app: simple
exit status 1
```

```
$ k apply -f 01_simple-rs-updated.yaml
replicaset.apps/simple configured
```

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-4vv7f   1/1     Running   0          28s
simple-s8n2f   1/1     Running   0          7m15s
```

### Scale to 50 replicas

```
$ k apply -f 02_simple-rs-50.yaml
replicaset.apps/simple configured
```

```
$ k get rs -w
NAME     DESIRED   CURRENT   READY   AGE
simple   50        50        18      9m16s
simple   50        50        19      9m18s
simple   50        50        20      9m18s
simple   50        50        21      9m18s
simple   50        50        22      9m18s
simple   50        50        23      9m18s
simple   50        50        24      9m19s
simple   50        50        25      9m19s
simple   50        50        26      9m19s
simple   50        50        27      9m19s
simple   50        50        28      9m20s
simple   50        50        29      9m20s
simple   50        50        30      9m21s
simple   50        50        31      9m21s
simple   50        50        32      9m22s
simple   50        50        33      9m23s
simple   50        50        34      9m24s
simple   50        50        35      9m24s
```

Check the pods that are not `Running`

```
$ k get pods --field-selector='status.phase!=Running'
NAME           READY   STATUS    RESTARTS   AGE
simple-2dpnz   0/1     Pending   0          3m31s
simple-5lqk2   0/1     Pending   0          3m31s
simple-6q82m   0/1     Pending   0          3m31s
simple-7j858   0/1     Pending   0          3m31s
simple-7wvm8   0/1     Pending   0          3m32s
simple-bwvbk   0/1     Pending   0          3m31s
simple-gh57p   0/1     Pending   0          3m31s
simple-gvlxt   0/1     Pending   0          3m31s
simple-lrfzs   0/1     Pending   0          3m32s
simple-qj97b   0/1     Pending   0          3m31s
simple-rszsv   0/1     Pending   0          3m31s
simple-tglzz   0/1     Pending   0          3m31s
simple-xbzcl   0/1     Pending   0          3m31s
simple-xfkhm   0/1     Pending   0          3m31s
simple-zdd5x   0/1     Pending   0          3m31s
```

```
$ k describe $(k get pods --field-selector='status.phase!=Running' --output name | head -n1)
Name:               simple-2dpnz
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
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-sclqf (ro)
Conditions:
  Type           Status
  PodScheduled   False
Volumes:
  default-token-sclqf:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-sclqf
    Optional:    false
QoS Class:       Burstable
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason            Age                  From               Message
  ----     ------            ----                 ----               -------
  Warning  FailedScheduling  41s (x6 over 3m58s)  default-scheduler  0/2 nodes are available: 2 Insufficient cpu.
```

We can see that the cannot be scheduled due to insufficient cpu count.

`Warning  FailedScheduling  41s (x6 over 3m58s)  default-scheduler  0/2 nodes are available: 2 Insufficient cpu.`

### Scale down back to 5 replicas


```
$ k scale rs/simple --replicas 5
replicaset.extensions/simple scaled
```

```
$ k get rs -w
NAME     DESIRED   CURRENT   READY   AGE
simple   5         50        35      16m
simple   5         50        35      16m
simple   5         5         5       16m
```

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
simple-7vq5f   1/1     Running   0          7m48s
simple-nprrb   1/1     Running   0          7m48s
simple-qk847   1/1     Running   0          7m48s
simple-qsgmr   1/1     Running   0          7m48s
simple-rccqx   1/1     Running   0          16m
```

## Selectors and Pods

### Deploy some _blue_ pods

```
$ k apply -f 04_simple-blue-pods.yaml
pod/simple-blue-pod-1 created
pod/simple-blue-pod-2 created
pod/simple-blue-pod-3 created
```

```
$ k get pods
NAME                READY   STATUS        RESTARTS   AGE
simple-7vq5f        1/1     Running       0          8m50s
simple-blue-pod-1   0/1     Terminating   0          3s
simple-blue-pod-2   0/1     Terminating   0          3s
simple-blue-pod-3   0/1     Terminating   0          3s
simple-nprrb        1/1     Running       0          8m50s
simple-qk847        1/1     Running       0          8m50s
simple-qsgmr        1/1     Running       0          8m50s
simple-rccqx        1/1     Running       0          17m
```

The new _blue_ pods get Terminated! Why??

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
  Type    Reason            Age                 From                   Message
  ----    ------            ----                ----                   -------
  Normal  SuccessfulCreate  21m                 replicaset-controller  Created pod: simple-rccqx
  Normal  SuccessfulCreate  15m                 replicaset-controller  Created pod: simple-t5dv5
  Normal  SuccessfulCreate  15m                 replicaset-controller  Created pod: simple-4b2q9
  Normal  SuccessfulCreate  15m                 replicaset-controller  Created pod: simple-thbgb
  Normal  SuccessfulCreate  15m                 replicaset-controller  Created pod: simple-9zjsh
  Normal  SuccessfulCreate  15m                 replicaset-controller  Created pod: simple-crmk7
  Normal  SuccessfulCreate  15m                 replicaset-controller  Created pod: simple-rjzgj
  Normal  SuccessfulCreate  15m                 replicaset-controller  Created pod: simple-c6kj5
  Normal  SuccessfulCreate  15m                 replicaset-controller  Created pod: simple-fqwn5
  Normal  SuccessfulCreate  15m (x17 over 15m)  replicaset-controller  (combined from similar events): Created pod: simple-nsd4p
  Normal  SuccessfulDelete  7s (x179 over 12m)  replicaset-controller  (combined from similar events): Deleted pod: simple-blue-pod-1
```

We can see that the ReplicaSet terminated those pods:

`Normal  SuccessfulDelete  7s (x179 over 12m)  replicaset-controller  (combined from similar events): Deleted pod: simple-blue-pod-1`

### Deploy a _blue_ replicaset

```
$ k apply -f 05_simple-blue-rs.yaml
replicaset.apps/simple-blue created
```

```
$ k get pods
NAME                READY   STATUS              RESTARTS   AGE
simple-7vq5f        1/1     Running             0          13m
simple-blue-bts4g   0/1     ContainerCreating   0          4s
simple-blue-ndrn9   0/1     ContainerCreating   0          4s
simple-blue-q87s9   0/1     ContainerCreating   0          4s
simple-blue-rlccs   0/1     ContainerCreating   0          4s
simple-blue-zgfr5   0/1     ContainerCreating   0          4s
simple-nprrb        1/1     Running             0          13m
simple-qk847        1/1     Running             0          13m
simple-qsgmr        1/1     Running             0          13m
simple-rccqx        1/1     Running             0          22m
```

```
$ k get pods
NAME                READY   STATUS    RESTARTS   AGE
simple-7vq5f        1/1     Running   0          13m
simple-blue-bts4g   1/1     Running   0          9s
simple-blue-ndrn9   1/1     Running   0          9s
simple-blue-q87s9   1/1     Running   0          9s
simple-blue-rlccs   1/1     Running   0          9s
simple-blue-zgfr5   1/1     Running   0          9s
simple-nprrb        1/1     Running   0          13m
simple-qk847        1/1     Running   0          13m
simple-qsgmr        1/1     Running   0          13m
simple-rccqx        1/1     Running   0          22m
```

```
$ k get rs
NAME          DESIRED   CURRENT   READY   AGE
simple        5         5         5       22m
simple-blue   5         5         5       12s
```

Now the pods stay, but why?

The selector is maching sets of pods, from most restrictive to less restrictive. So `rs/simple` with manage all pods with label: `app: simple` that doesn't match any other replicaset.

### ReplicaSet for non-colored pods only

The new selector for the `rs/simple-nocolor` will be:

```yaml
  selector:
    matchLabels:
      app: simple
    matchExpressions:
      - { key: color, operator: DoesNotExist }

```

```
$ k get rs
NAME             DESIRED   CURRENT   READY   AGE
simple           5         5         5       28m
simple-blue      5         5         5       5m33s
simple-nocolor   5         5         5       5s
```

Let's create some orange pods:

```
$ k apply -f 08_simple-orange-pods.yaml
pod/simple-orange-pod-1 created
pod/simple-orange-pod-2 created
pod/simple-orange-pod-3 created
```

```
$ k get pods -l color=orange
NAME                  READY   STATUS        RESTARTS   AGE
simple-orange-pod-1   0/1     Terminating   0          2s
simple-orange-pod-2   0/1     Terminating   0          2s
simple-orange-pod-3   0/1     Terminating   0          2s
```

They are still getting delted by the `rs/simple` controller.

```
$ k delete rs/simple
replicaset.extensions "simple" deleted
```

```
$ k get pods -l color=orange
NAME                  READY   STATUS    RESTARTS   AGE
simple-orange-pod-1   1/1     Running   0          19s
simple-orange-pod-2   1/1     Running   0          19s
simple-orange-pod-3   1/1     Running   0          18s
```

### Let's acquire those fancy orange hosts

```
$ k apply -f 09_simple-orange-rs.yaml
replicaset.apps/simple-orange created
```

```
$ k get pods -l color=orange
NAME                  READY   STATUS    RESTARTS   AGE
simple-orange-5qclw   1/1     Running   0          8s
simple-orange-bs9qn   1/1     Running   0          8s
simple-orange-c92pj   1/1     Running   0          8s
simple-orange-pod-1   1/1     Running   0          14m
simple-orange-pod-2   1/1     Running   0          14m
simple-orange-pod-3   1/1     Running   0          14m
```

## Container probes

### Readiness probe

Let's add a readiness probe, on the port 80:

- Wait 10 secs before start probing
- Each 5 seconds, check the probe
- Mark as healthy after 3 consecutive OK checks

```
$ k apply -f 10_probes-rs-readiness.yaml
replicaset.apps/probes created
```

```
$ k get pods -l app=probes -w;
NAME           READY   STATUS              RESTARTS   AGE
probes-wx9l6   0/1     ContainerCreating   0          0s
probes-xkblx   0/1     ContainerCreating   0          0s
probes-xkblx   0/1     Running             0          2s
probes-wx9l6   0/1     Running             0          3s
probes-xkblx   1/1     Running             0          25s
probes-wx9l6   1/1     Running             0          26s
```

Deploy some pods with failing ReadinessProbes:

```
$ k apply -f 11_probes-rs-readiness-ko.yaml; k get pods -l app=probes -w
replicaset.apps/probes configured
NAME           READY   STATUS              RESTARTS   AGE
probes-fq42v   0/1     ContainerCreating   0          1s
probes-lpz6d   0/1     ContainerCreating   0          1s
probes-wx9l6   1/1     Running             0          85s
probes-xkblx   1/1     Running             0          85s
probes-fq42v   0/1     Running             0          2s
probes-lpz6d   0/1     Running             0          3s
```

They are not getting ready

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
probes-fq42v   0/1     Running   0          40s
probes-lpz6d   0/1     Running   0          40s
probes-wx9l6   1/1     Running   0          2m4s
probes-xkblx   1/1     Running   0          2m4s
```

And if we look the status of one of the `READY 0/1` pods, we'll see the reason in the `Events:` section:

`Warning  Unhealthy  64s (x22 over 2m49s)  kubelet, cnbcn-k8s-study-jam-np-fq1k  Readiness probe failed: dial tcp 10.244.1.240:81: connect: connection refused`

### Liveness probe

```
$ k apply -f 12_probes-rs-liveness.yaml
replicaset.apps/probes configured
```

```
$ k get pods -w
NAME           READY   STATUS    RESTARTS   AGE
probes-dscfm   0/1     Running   0          20s
probes-fq42v   0/1     Running   0          4m51s
probes-lpz6d   0/1     Running   0          4m51s
probes-wx9l6   1/1     Running   0          6m15s
probes-xkblx   1/1     Running   0          6m15s
probes-xkqhd   0/1     Running   0          20s
probes-xkqhd   1/1     Running   0          23s
probes-dscfm   1/1     Running   0          24s
```

```
$ k apply -f 13_probes-rs-liveness-ko.yaml
replicaset.apps/probes configured
```

```
$ k get pods -w
NAME           READY   STATUS    RESTARTS   AGE
probes-dscfm   1/1     Running   0          4m44s
probes-fq42v   0/1     Running   0          9m15s
probes-lpz6d   0/1     Running   0          9m15s
probes-nn4qx   0/1     Running   0          5s
probes-wx9l6   1/1     Running   0          10m
probes-xgsdw   0/1     Running   0          5s
probes-xkblx   1/1     Running   0          10m
probes-xkqhd   1/1     Running   0          4m44s
probes-nn4qx   0/1     Running   1          19s
probes-xgsdw   0/1     Running   1          23s
probes-nn4qx   1/1     Running   1          29s
probes-xgsdw   1/1     Running   1          32s
probes-xgsdw   0/1     Running   2          37s
probes-nn4qx   0/1     Running   2          40s
probes-xgsdw   1/1     Running   2          47s
probes-nn4qx   1/1     Running   2          49s
probes-xgsdw   0/1     Running   3          52s
probes-nn4qx   0/1     Running   3          59s
probes-xgsdw   1/1     Running   3          62s
```

We will start seeing `CrashLoopBackOff` status:

```
$ k get pods
NAME           READY   STATUS             RESTARTS   AGE
probes-dscfm   1/1     Running            0          6m16s
probes-fq42v   0/1     Running            0          10m
probes-lpz6d   0/1     Running            0          10m
probes-nn4qx   1/1     Running            4          97s
probes-wx9l6   1/1     Running            0          12m
probes-xgsdw   0/1     CrashLoopBackOff   3          97s
probes-xkblx   1/1     Running            0          12m
probes-xkqhd   1/1     Running            0          6m16s
```

```
$ k get pods
NAME           READY   STATUS             RESTARTS   AGE
probes-dscfm   1/1     Running            0          24m
probes-fq42v   0/1     Running            0          29m
probes-lpz6d   0/1     Running            0          29m
probes-nn4qx   0/1     CrashLoopBackOff   12         20m
probes-wx9l6   1/1     Running            0          30m
probes-xgsdw   0/1     CrashLoopBackOff   11         20m
probes-xkblx   1/1     Running            0          30m
probes-xkqhd   1/1     Running            0          24m
```

## Deploy a new image


```
$ k apply -f 15-probes-rs-update-image.yaml
replicaset.apps/probes created
(do-fra1-cnbcn-k8s-study-jam) rael@W001062:replicasets (master)
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
probes-5r57b   1/1     Running   0          12s
probes-pzj55   1/1     Running   0          12s
probes-qpv5j   1/1     Running   0          12s
```

```
$ k apply -f 16_probes-rs-update-image-ko.yaml
replicaset.apps/probes configured
```

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
probes-5r57b   1/1     Running   0          2m21s
probes-pzj55   1/1     Running   0          2m21s
probes-qpv5j   1/1     Running   0          2m21s
(do-fra1-cnbcn-k8s-study-jam) rael@W001062:replicasets (master)
$ $ k get pods -l app=probes -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
```

```
$ k get pods -l app=probes -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
NAME           IMAGE             STATUS
probes-5r57b   raelga/cats:neu   Running
probes-pzj55   raelga/cats:neu   Running
probes-qpv5j   raelga/cats:neu   Running
```

```
$ k get pods -l app=probes -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
NAME           IMAGE             STATUS
probes-5r57b   raelga/cats:neu   Running
probes-pzj55   raelga/cats:neu   Running
probes-qpv5j   raelga/cats:neu   Running
```

```
$ k apply -f 17_probes-rs-6-update-image-ko.yaml
replicaset.apps/probes configured
```

```
$ k get pods
NAME           READY   STATUS              RESTARTS   AGE
probes-5r57b   1/1     Running             0          3m19s
probes-cj2ws   0/1     ContainerCreating   0          3s
probes-dvpvr   0/1     ContainerCreating   0          3s
probes-lnp7j   0/1     Running             0          3s
probes-pzj55   1/1     Running             0          3m19s
probes-qpv5j   1/1     Running             0          3m19s
```

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
probes-5r57b   1/1     Running   0          3m22s
probes-cj2ws   0/1     Running   0          6s
probes-dvpvr   0/1     Running   0          6s
probes-lnp7j   0/1     Running   0          6s
probes-pzj55   1/1     Running   0          3m22s
probes-qpv5j   1/1     Running   0          3m22s
```

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
probes-5r57b   1/1     Running   0          4m10s
probes-cj2ws   0/1     Running   0          54s
probes-dvpvr   0/1     Running   0          54s
probes-lnp7j   0/1     Running   0          54s
probes-pzj55   1/1     Running   0          4m10s
probes-qpv5j   1/1     Running   0          4m10s
```

`  Warning  Unhealthy  8s (x4 over 38s)  kubelet, cnbcn-k8s-study-jam-np-fq1k  Readiness probe failed: HTTP probe failed with statuscode: 404`

```
$ k apply -f 18_probes-rs-9-update-image-ok.yaml
replicaset.apps/probes configured
```

```
$ k get pods -l app=probes -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
NAME           IMAGE                STATUS
probes-5r57b   raelga/cats:neu      Running
probes-9fqt6   raelga/cats:blanca   Pending
probes-cj2ws   raelga/cats:blanca   Running
probes-ckhjt   raelga/cats:blanca   Pending
probes-dvpvr   raelga/cats:blanca   Running
probes-h5zgj   raelga/cats:blanca   Pending
probes-lnp7j   raelga/cats:blanca   Running
probes-pzj55   raelga/cats:neu      Running
probes-qpv5j   raelga/cats:neu      Running
```

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
probes-5r57b   1/1     Running   0          7m1s
probes-9fqt6   1/1     Running   0          18s
probes-cj2ws   0/1     Running   0          3m45s
probes-ckhjt   1/1     Running   0          18s
probes-dvpvr   0/1     Running   0          3m45s
probes-h5zgj   1/1     Running   0          18s
probes-lnp7j   0/1     Running   0          3m45s
probes-pzj55   1/1     Running   0          7m1s
probes-qpv5j   1/1     Running   0          7m1s
```

```
$ k delete pods probes-dvpvr probes-lnp7j probes-cj2ws
pod "probes-dvpvr" deleted
pod "probes-lnp7j" deleted
pod "probes-cj2ws" deleted
```

```
$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
probes-5r57b   1/1     Running   0          8m21s
probes-9fqt6   1/1     Running   0          98s
probes-9nc28   1/1     Running   0          14s
probes-ckhjt   1/1     Running   0          98s
probes-h5zgj   1/1     Running   0          98s
probes-hwbpj   1/1     Running   0          14s
probes-ljv4j   1/1     Running   0          14s
probes-pzj55   1/1     Running   0          8m21s
probes-qpv5j   1/1     Running   0          8m21s
```

```
$ k get pods -l app=probes -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
NAME           IMAGE                STATUS
probes-5r57b   raelga/cats:neu      Running
probes-9fqt6   raelga/cats:blanca   Running
probes-cj2ws   raelga/cats:blanca   Running
probes-ckhjt   raelga/cats:blanca   Running
probes-dvpvr   raelga/cats:blanca   Running
probes-h5zgj   raelga/cats:blanca   Running
probes-lnp7j   raelga/cats:blanca   Running
probes-pzj55   raelga/cats:neu      Running
probes-qpv5j   raelga/cats:neu      Running
```

```
$ k delete pods probes-pzj55 probes-qpv5j probes-5r57b
pod "probes-pzj55" deleted
pod "probes-qpv5j" deleted
pod "probes-5r57b" deleted
```

```
$ k get pods -l app=probes -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
NAME           IMAGE                STATUS
probes-9fqt6   raelga/cats:blanca   Running
probes-9nc28   raelga/cats:blanca   Running
probes-ckhjt   raelga/cats:blanca   Running
probes-h5zgj   raelga/cats:blanca   Running
probes-hjd2m   raelga/cats:blanca   Running
probes-hwbpj   raelga/cats:blanca   Running
probes-ljv4j   raelga/cats:blanca   Running
probes-n7mhl   raelga/cats:blanca   Running
probes-w9sgv   raelga/cats:blanca   Running
```