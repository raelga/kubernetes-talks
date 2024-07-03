# Lifecycle

In this section, we will go through the lifecycle of a Kubernetes pod.

First, we apply a configuration file to create a new pod:

```sh
kubectl apply -f busybox-probes-readiness-ko.yml
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
kubectl apply -f busybox-probes-readiness-ok.yml
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
kubectl apply -f pod-health-cmd-readiness.yml
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
Type Reason Age From Message

---

Normal Scheduled 66s default-scheduler Successfully assigned default/readiness-cmd to kind-control-plane
Normal Pulling 66s kubelet Pulling image "k8s.gcr.io/busybox"
Normal Pulled 65s kubelet Successfully pulled image "k8s.gcr.io/busybox" in 812ms (812ms including waiting)
Normal Created 65s kubelet Created container readiness
Normal Started 65s kubelet Started container readiness
Warning Unhealthy 1s (x11 over 56s) kubelet Readiness probe failed: cat: can't open '/tmp/healthy': No such file or directory

```

Now we can review how a liveness probe works.

Deploy the following configuration file:

```sh
kubectl apply -f pod-health-http-liveness.yml
```

The expected output is:

```
pod/liveness-http created
```

Using the get with a watch flag, we can see the pod starting and
eventually will start rebooting.

```sh
kubectl get pods -w
```

```
NAME            READY   STATUS              RESTARTS    AGE
liveness-http   0/1     ContainerCreating   0           3s
liveness-http   1/1     Running             0           5s
liveness-http   1/1     Running             0           3s
liveness-http   1/1     Running             1 (2s ago)  21s
liveness-http   1/1     Running             2 (2s ago)  39s
```

Again, using the describe command, we can see the events of the pod and
the reason why the pod is being restarted:

```sh
kubectl describe pods liveness-http
```

```
Name: liveness-http
...
Type Reason Age From Message

---

Normal Scheduled 21s default-scheduler Successfully assigned default/liveness-http to kind-control-plane
Normal Pulled 19s kubelet Successfully pulled image "k8s.gcr.io/liveness" in 1.605s (1.605s including waiting)
Normal Created 19s kubelet Created container liveness
Normal Started 19s kubelet Started container liveness
Normal Pulling 0s (x2 over 21s) kubelet Pulling image "k8s.gcr.io/liveness"
Warning Unhealthy 0s (x3 over 6s) kubelet Liveness probe failed: HTTP probe failed with statuscode: 500
Normal Killing 0s kubelet Container liveness failed liveness probe, will be restarted
```

```

```
