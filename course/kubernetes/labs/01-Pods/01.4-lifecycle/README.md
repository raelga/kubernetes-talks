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

The event shows that the readiness probe failed because the file `/tmp/healthy` does not exist. This example creates the file after 20 seconds, then removes it 10 seconds later, so the pod is briefly ready before becoming not ready again.

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

`01-readiness-probe-failing.yaml` and `03-readiness-exec.yaml` demonstrate
the same readiness behavior: both create `/tmp/healthy` temporarily and then
remove it, so the pod becomes ready and later not ready without a restart.
They differ in timing: 01 creates the file after 20 seconds and checks every
second after a 15-second initial delay; 03 creates it after 30 seconds and
checks every 5 seconds after a 5-second initial delay. Both remove it 10
seconds after creation. Their pod names, container names and labels also differ.


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

After ~35 seconds the file is removed. Two failed checks trigger a restart; the default termination grace period and probe scheduling can delay the visible restart count.

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

## Go HTTP health checks with a Service

This example uses the existing [hello-world-go](../../00-Kind/hello-world-go/) application. Build and load its image into every node of your kind cluster (replace `kind` with your cluster name if different):

```sh
docker build -t hello-world-go:probes ../../00-Kind/hello-world-go
kind load docker-image hello-world-go:probes --name kind
kubectl apply -f 08-hello-world-go.yaml
kubectl wait --for=condition=Ready pod/hello-world-probes --timeout=120s
kubectl get pod hello-world-probes
kubectl describe pod hello-world-probes
kubectl get endpointslice -l kubernetes.io/service-name=hello-world-probes
kubectl port-forward service/hello-world-probes 8080:8080
```

In a second terminal:

```sh
curl http://localhost:8080/
curl -i http://localhost:8080/health
```

Both HTTP probes use `/health`, which this simple application always returns as HTTP 200 while its HTTP server responds. Readiness determines whether the Pod receives normal Service traffic; failed liveness restarts the container. Because this application has no independently controllable health states, use the following Service exercise to demonstrate each failure separately.

Stop port-forward with Ctrl+C, then clean up:

```sh
kubectl delete -f 08-hello-world-go.yaml
```

## Service with readiness and liveness probes

`07-probes-service.yaml` creates two BusyBox web Pods, a Service, and a
client Pod that repeatedly requests the Service. Separate exec probes check
`/tmp/ready` and `/tmp/live`; these are switches for the exercise, not real
application health checks. Run in a cluster with DNS enabled:

```sh
kubectl apply -f 07-probes-service.yaml
kubectl wait --for=condition=Ready pod/probes-service-demo-1 pod/probes-service-demo-2 pod/probes-service-client --timeout=120s
kubectl logs -f probes-service-client
```

The responses identify the backend. Stop following the logs with Ctrl-C; the
client continues running. Distribution need not be even. Unlike this
in-cluster client, `kubectl port-forward service/...` selects one backing Pod
for the forwarding session.

In another terminal, remove the readiness switch from one backend:

```sh
kubectl exec probes-service-demo-1 -- rm /tmp/ready
kubectl get pods -l app=probes-service-demo -w
```

When Pod 1 shows `0/1`, stop the watch. Its restart count is unchanged.
Inspect the EndpointSlice and client logs after allowing routing to converge:

```sh
kubectl get endpointslices -l kubernetes.io/service-name=probes-service-demo -o yaml
kubectl logs --tail=20 -f probes-service-client
```

Pod 1's endpoint can remain listed with `conditions.ready: false`; new Service
connections should reach Pod 2. Readiness does not terminate existing
connections. Restore Pod 1:

```sh
kubectl exec probes-service-demo-1 -- touch /tmp/ready
kubectl wait --for=condition=Ready pod/probes-service-demo-1 --timeout=120s
```

Now trigger a liveness failure and observe the restart:

```sh
kubectl exec probes-service-demo-1 -- rm /tmp/live
kubectl get pod probes-service-demo-1 -w
```

Stop the watch once `RESTARTS` increases. Startup recreates both switches,
and the Pod becomes Ready again. Use `kubectl describe pod probes-service-demo-1`
to inspect probe events.

Clean up all three Pods and the Service:

```sh
kubectl delete -f 07-probes-service.yaml
```

### Cleanup

```sh
kubectl delete -f 01-readiness-probe-failing.yaml
kubectl delete -f 02-readiness-probe-passing.yaml
kubectl delete -f 03-readiness-exec.yaml
kubectl delete -f 04-liveness-exec.yaml
kubectl delete -f 05-probes-tcp.yaml
kubectl delete -f 06-probes-exec.yaml
```
