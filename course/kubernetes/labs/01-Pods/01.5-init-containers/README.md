# Init Containers

The following configuration file defines a pod with two init containers:

````yaml
```sh
kubectl apply -f busybox-init-containers.yml
````

The expected output is:

```
pod/busybox-init-containers created
```

And we can check the status of the pod:

```sh
kubectl get pods
```

And see the pod starting with the init containers:

```
NAME                    READY STATUS    RESTARTS AGE
busybox-init-containers 0/1   Init:0/2  0        2s

```

We can get more details about the pod using the describe command:

```sh
kubectl describe pods
```

In the Events section, we can see the status of the init containers:

```
...
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  3s    default-scheduler  Successfully assigned default/busybox-init-containers to kind-control-plane
  Normal  Pulling    2s    kubelet            Pulling image "raelga/toolbox"
  Normal  Pulled     2s    kubelet            Successfully pulled image "raelga/toolbox" in 941ms (941ms including waiting)
  Normal  Created    2s    kubelet            Created container init-dummy-svc-wait
  Normal  Started    1s    kubelet            Started container init-dummy-svc-wait
  Normal  Pulled     1s    kubelet            Container image "google/cloud-sdk:245.0.0-alpine" already present on machine
  Normal  Created    1s    kubelet            Created container init-gcloud-sdk
  Normal  Started    0s    kubelet            Started container init-gcloud-sdk
  Normal  Pulling    0s    kubelet            Pulling image "busybox"
```

Logs of the init container show that the init containers are waiting for the dummy-svc service to be available:

```sh
kubectl logs -f busybox-init-containers -c init-dummy-svc-wait
```

```
Server: 10.96.0.10
Address: 10.96.0.10#53

\*\* server can't find dummy-svc: NXDOMAIN

waiting for dummy-svc
Server: 10.96.0.10
Address: 10.96.0.10#53

\*\* server can't find dummy-svc: NXDOMAIN

waiting for dummy-svc
Server: 10.96.0.10
Address: 10.96.0.10#53

```

So we can create a dummy service to make the init containers finish:

```sh
kubectl apply -f busybox-init-containers-dummy-svc.yaml
```

```
service/dummy-svc created
```

After creating the service, we can check the status of the pod:

```sh
kubectl get pods -w
```

And we can see the init containers finishing:

```
NAME READY STATUS RESTARTS AGE
busybox-init-containers 0/1 Init:0/2 0 20s
busybox-init-containers 0/1 Init:1/2 0 68s
busybox-init-containers 0/1 PodInitializing 0 69s
busybox-init-containers 0/1 Running 0 71s
busybox-init-containers 1/1 Running 0 86s

```
