# Lifecycle

In this section, we will go through the lifecycle of a Kubernetes pod.

First, we apply a configuration file to create a new pod:

```sh
kubectl apply -f 01-readiness-probe-failing.yaml
```

After applying the configuration, we get a confirmation that the pod has been created:

```
pod/busybox-probes-readiness-ko created
```

We can then check the status of our pods using the `kubectl get pods` command:

```sh
kubectl get pods
```

At this point, the pod is still being created:

```
NAME                          READY   STATUS              RESTARTS   AGE
busybox-probes-readiness-ko   0/1     ContainerCreating   0          2s
```

After a few seconds, we check the status of the pods again:

```sh
kubectl get pods
```

Now, the pod is running:

```
NAME                          READY   STATUS    RESTARTS   AGE
busybox-probes-readiness-ko   0/1     Running   0          6s
```

We can get more detailed information about the pod using the `kubectl describe pods` command:

```sh
kubectl describe pods
```

The output provides detailed information about the pod, check the last event.

```
Name:             busybox-probes-readiness-ko
Namespace:        default
Priority:         0
...
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  48s                default-scheduler  Successfully assigned default/busybox-probes-readiness-ko to kind-control-plane
  Normal   Pulling    47s                kubelet            Pulling image "busybox"
  Normal   Pulled     46s                kubelet            Successfully pulled image "busybox" in 935ms (935ms including waiting)
  Normal   Created    46s                kubelet            Created container busybox
  Normal   Started    46s                kubelet            Started container busybox
  Warning  Unhealthy  2s (x10 over 45s)  kubelet            Readiness probe failed: cat: can't open '/tmp/healthy': No such file or directory
```

The last event shows that the readiness probe failed because the file `/tmp/healthy` does not exist in the container.

Now we can deploy the correct configuration file:

```sh
kubectl apply -f 02-readiness-probe-passing.yaml
```

The expected output is:

```
pod/busybox-probes-readiness-ok created
```

And we can check the status of the pods:

```sh
kubectl get pods -w
```

We should see the pod starting not ready and eventually becoming ready after
the readiness probe is successful:

```
NAME                          READY   STATUS    RESTARTS   AGE
busybox-probes-readiness-ok   0/1     Running   0          3s
busybox-probes-readiness-ok   1/1     Running   0          15s
```

# Readiness vs Liveness

Deploy the following configuration file:

```sh
kubectl apply -f 03-readiness-exec.yaml
```

The expected output is:

```
pod/readiness-cmd created
```

Watch the status of the pod:

```sh
kubectl get pods -w
```

The pod starts not being ready and eventually becomes ready after the
readiness probe is successful. After a while, the pod becomes not ready
because the command probe fails, but is not restarted.

```
NAME          READY STATUS            RESTARTS  AGE
readiness-cmd 0/1   ContainerCreating 0         2s
readiness-cmd 0/1   Running           0         2s
readiness-cmd 1/1   Running           0         35s
readiness-cmd 0/1   Running           0         55s
```

Using the describe command, we can see the events of the pod and
why the Ready status has changed:

```sh
kubectl describe pods readiness-cmd
```

```
Name: readiness-cmd
...
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  66s                default-scheduler  Successfully assigned default/readiness-cmd to kind-control-plane
  Normal   Pulling    66s                kubelet            Pulling image "busybox"
  Normal   Pulled     65s                kubelet            Successfully pulled image "busybox" in 812ms (812ms including waiting)
  Normal   Created    65s                kubelet            Created container readiness
  Normal   Started    65s                kubelet            Started container readiness
  Warning  Unhealthy  1s (x11 over 56s)  kubelet            Readiness probe failed: cat: can't open '/tmp/healthy': No such file or directory
```

Now we can review how a liveness probe works. Unlike readiness probes,
when a liveness probe fails the container is **restarted**.

Deploy the following configuration file:

```sh
kubectl apply -f 04-liveness-exec.yaml
```

```
pod/liveness-cmd created
```

The container creates `/tmp/healthy` after 5 seconds, then removes it after 30 seconds. The liveness probe checks for this file every 5 seconds.

```sh
kubectl get pods -w
```

```
NAME            READY   STATUS    RESTARTS     AGE
liveness-cmd    1/1     Running   0            10s
liveness-cmd    1/1     Running   1 (2s ago)   45s
```

After ~35 seconds the file is removed, the probe fails, and the container restarts. Using describe we can see the failure:

```sh
kubectl describe pod liveness-cmd | tail -5
```

```
  Warning  Unhealthy  5s (x2 over 10s)  kubelet  Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
  Normal   Killing    5s                kubelet  Container liveness failed liveness probe, will be restarted
```

## TCP probes (liveness and readiness)

The `05-probes-tcp.yaml` manifest defines a pod with both a TCP readiness probe and a TCP liveness probe on the same port:

```sh
kubectl apply -f 05-probes-tcp.yaml
```

```
pod/goproxy created
```

Watch the pod status:

```sh
kubectl get pods -w
```

```
NAME      READY   STATUS    RESTARTS   AGE
goproxy   0/1     Running   0          3s
goproxy   1/1     Running   0          6s
```

The readiness probe checks the TCP socket on port 8080 every 10 seconds (after an initial 5 second delay). The liveness probe checks the same port every 20 seconds (after an initial 15 second delay). If the TCP connection fails, the readiness probe marks the pod as not ready, while the liveness probe restarts the container.

```sh
kubectl describe pod goproxy | grep -A5 "Readiness\|Liveness"
```

```
    Liveness:       tcp-socket :8080 delay=15s timeout=1s period=20s #success=1 #failure=3
    Readiness:      tcp-socket :8080 delay=5s timeout=1s period=10s #success=1 #failure=3
```

## Combined probes (readiness and liveness)

The `06-probes-exec.yaml` manifest defines a pod with both readiness and liveness probes using exec commands. The container creates `/tmp/live` and `/tmp/ready` on startup.

```sh
kubectl apply -f 06-probes-exec.yaml
```

```
pod/probes-cmd created
```

```sh
kubectl get pods -w
```

```
NAME         READY   STATUS    RESTARTS   AGE
probes-cmd   0/1     Running   0          2s
probes-cmd   1/1     Running   0          12s
```

You can manually trigger probe failures by deleting the files:

```sh
kubectl exec probes-cmd -- rm /tmp/ready
```

The pod becomes not ready (but is not restarted):

```sh
kubectl get pods
```

```
NAME         READY   STATUS    RESTARTS   AGE
probes-cmd   0/1     Running   0          30s
```

Now delete the liveness file:

```sh
kubectl exec probes-cmd -- rm /tmp/live
```

The container is restarted because the liveness probe fails:

```sh
kubectl get pods -w
```

```
NAME         READY   STATUS    RESTARTS      AGE
probes-cmd   0/1     Running   1 (2s ago)    35s
probes-cmd   1/1     Running   1 (12s ago)   45s
```

After restart, both files are recreated and the pod becomes ready again.

### Cleanup

```sh
kubectl delete -f 01-readiness-probe-failing.yaml
kubectl delete -f 02-readiness-probe-passing.yaml
kubectl delete -f 03-readiness-exec.yaml
kubectl delete -f 04-liveness-exec.yaml
kubectl delete -f 05-probes-tcp.yaml
kubectl delete -f 06-probes-exec.yaml
```
