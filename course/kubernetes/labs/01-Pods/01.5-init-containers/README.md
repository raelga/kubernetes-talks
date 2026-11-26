# Init Containers

The following configuration file defines a pod with two init containers:

```sh
kubectl apply -f 01-init-containers.yaml
```

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

Before the Service exists, the first init container remains running and the pod
stays in `Init:0/2`. Its logs below explain the wait; the second init container
and application container cannot start until it completes.

The first init container waits for the `dummy-svc` DNS name to resolve. This checks that the Service exists in DNS, not that it has endpoints or serves traffic:

```sh
kubectl logs -f busybox-init-containers -c init-dummy-svc-wait
```

```
Server: 10.96.0.10
Address: 10.96.0.10#53

** server can't find dummy-svc: NXDOMAIN

waiting for dummy-svc
Server: 10.96.0.10
Address: 10.96.0.10#53

** server can't find dummy-svc: NXDOMAIN

waiting for dummy-svc
Server: 10.96.0.10
Address: 10.96.0.10#53

```

Create the dummy Service so the first init container can resolve its name and the next init container can start. Stop following the logs with Ctrl-C first:

```sh
kubectl apply -f 02-dummy-service.yaml
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

### Cleanup

```sh
kubectl delete -f 01-init-containers.yaml
kubectl delete -f 02-dummy-service.yaml
```
