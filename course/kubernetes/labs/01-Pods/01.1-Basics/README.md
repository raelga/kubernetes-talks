# Pods

## Shell

To create a pod using the configuration in `shell.yaml`, run the following command:

```sh
kubectl apply -f shell.yaml
```

After running the command, you should see an output similar to this, indicating that the pod was created successfully:

```
pod/shell created
```

To verify that the pod is running, you can list all the pods using the following command:

```sh
kubectl get pods
```

The output will look something like this, showing the status of all the pods currently running in your Kubernetes cluster:

```
NAME   READY   STATUS    RESTARTS   AGE
shell        1/1     Running   0          6s
```

The above output shows the status of all running pods. The shell pod is running and has not restarted since it was created 6 seconds ago.

To get more detailed information about the pods, including the node they are running on and their IP addresses, you can use the -o wide option:

```sh
kubectl get pods -o wide
```

This command will display additional details about each pod, such as the IP address and the node where the pod is running.

```sh
NAME        READY   STATUS    RESTARTS   AGE     IP           NODE                 NOMINATED NODE   READINESS GATES
shell        1/1     Running   0          14s     10.244.0.5   kind-control-plane   <none>           <none>
```

To get the YAML representation of the pod, you can use the `-o yaml` option:

```sh
kubectl get -o yaml pod shell
```

This command will display the YAML representation of the pod, including its IP address and start time.

```
apiVersion: v1
kind: Pod
metadata:
  annotations:
...
  podIPs:
  - ip: 10.244.0.40
  qosClass: BestEffort
  startTime: "2024-07-01T15:49:20Z"
```

To view and edit the pod configuration with your default text editor, you can use the `kubectl edit` command:

```sh
kubectl edit pod shell
```

To get human friendly detailed information about the pod, you can use the `kubectl describe` command:

```sh
kubectl describe pod shell
```

This command will display detailed information about the pod, including its status, IP address, and container details.

```
Name:             shell
Namespace:        default
Priority:         0
Service Account:  default
Node:             kind-control-plane/10.89.0.2
Start Time:       Mon, 01 Jul 2024 17:49:20 +0200
Labels:           app=shell
Annotations:      <none>
Status:           Running
IP:               10.244.0.40
IPs:
  IP:  10.244.0.40
Containers:
  shell:
    Container ID:  containerd://fe4330a2e50c113cf96a372a18240c2732bca1e5cf0b34c29d9bec4be6911f5a
    Image:         raelga/toolbox
    Image ID:      docker.io/raelga/toolbox@sha256:f00ba6e35834302667500576630a5b1b42cffd782ff5e8a3f2b95f09f230b751
    Port:          <none>
    Host Port:     <none>
    Command:
      bash
      -c
      sleep 3600
    State:          Running
      Started:      Mon, 01 Jul 2024 17:49:21 +0200
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-5z8f9 (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       True
  ContainersReady             True
  PodScheduled                True
Volumes:
  kube-api-access-5z8f9:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  26m   default-scheduler  Successfully assigned default/shell to kind-control-plane
  Normal  Pulling    26m   kubelet            Pulling image "raelga/toolbox"
  Normal  Pulled     26m   kubelet            Successfully pulled image "raelga/toolbox" in 1.005s (1.005s including waiting)
  Normal  Created    26m   kubelet            Created container shell
  Normal  Started    26m   kubelet            Started container shell
```

To interact with the running pod, you can use the `kubectl exec` command followed by `-ti` (which stands for "terminal interactive"), the name of the pod, and the shell command:

```sh
kubectl exec -ti shell -- /bin/sh
```

To display the currently running processes in the pod, you can use the ps aux command:

```sh
ps aux
```

The output will look something like this, showing the currently running processes:

```
PID   USER     TIME  COMMAND
    1 root      0:00 sleep 3600
   13 root      0:00 /bin/sh
   18 root      0:00 ps aux
```

To delete the pod, you can use the `kubectl delete` command followed by `-f and the name of the configuration file:

```sh
kubectl delete -f shell.yaml
```

The output will confirm that the pod was deleted:

```
pod "shell" deleted
```

## Hello Sh

The output will confirm that the pod was created:

```sh
kubectl apply -f hello-sh.yaml
```

The output will confirm that the pod was created:

```
pod/hello-sh created
```

To view the logs of the `hello-sh`` pod, use the following command:

```sh
kubectl logs -f hello-sh
```

The output will display the message printed by the `hello-sh`` pod:

```
Hello Kubernetes from hello-sh!
```

To see the differences between the `hello-sh.yaml` and `hello-sh-updated.yaml` files, use the `diff` command:

```sh
diff hello-sh.yaml hello-sh-updated.yaml
```

The output will show the lines that differ between the two files:

```
8d7
<     tier: demo
13c12
<     command: ['sh', '-c', 'echo Hello Kubernetes from $(hostname)! && sleep 30']
---
>     command: ['sh', '-c', 'echo Hello Kubernetes from $(hostname)! && sleep 3600']

```

To update the `hello-sh` pod with the configuration in `hello-sh-updated.yaml`, run the following command:

```sh
kubectl apply -f hello-sh-updated.yaml
```

However, you may encounter an error message like the one below. This is because some fields in the pod spec cannot be updated once the pod is created.

```
The Pod "hello-sh" is invalid: spec: Forbidden: pod updates may not change fields other than `spec.containers[*].image`,`spec.initContainers[*].image`,`spec.activeDeadlineSeconds`,`spec.tolerations` (only additions to existing tolerations),`spec.terminationGracePeriodSeconds` (allow it to be set to 1 if it was previously negative)
  core.PodSpec{
        Volumes:        {{Name: "kube-api-access-4ckz5", VolumeSource: {Projected: &{Sources: {{ServiceAccountToken: &{ExpirationSeconds: 3607, Path: "token"}}, {ConfigMap: &{LocalObjectReference: {Name: "kube-root-ca.crt"}, Items: {{Key: "ca.crt", Path: "ca.crt"}}}}, {DownwardAPI: &{Items: {{Path: "namespace", FieldRef: &{APIVersion: "v1", FieldPath: "metadata.namespace"}}}}}}, DefaultMode: &420}}}},
        InitContainers: nil,
        Containers: []core.Container{
                {
                        Name:  "hello-sh",
                        Image: "busybox",
                        Command: []string{
                                "sh",
                                "-c",
                                strings.Join({
                                        "echo Hello Kubernetes from $(hostname)! && sleep 3",
+                                       "60",
                                        "0",
                                }, ""),
                        },
                        Args:       nil,
                        WorkingDir: "",
                        ... // 19 identical fields
                },
        },
        EphemeralContainers: nil,
        RestartPolicy:       "Always",
        ... // 28 identical fields
  }
```

To delete the `hello-sh` pod, run the following command:

```sh
kubectl delete pod hello-sh
```

The output will confirm that the pod was deleted:

```
pod "hello-sh" deleted
```

## Hello Web

To create a new pod using the configuration in `hello-web.yml`, run the following command:

```sh
kubectl apply -f hello-web.yml
```

The output will confirm that the pod was created:

```
pod/hello-web created
```

To view the logs of the `hello-web` pod, use the following command:

```sh
kubectl logs -f hello-web
```

The output will display the startup logs of the `hello-web` pod:

```
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2024/07/01 15:50:38 [notice] 1#1: using the "epoll" event method
2024/07/01 15:50:38 [notice] 1#1: nginx/1.27.0
2024/07/01 15:50:38 [notice] 1#1: built by gcc 12.2.0 (Debian 12.2.0-14)
2024/07/01 15:50:38 [notice] 1#1: OS: Linux 6.8.8-300.fc40.x86_64
2024/07/01 15:50:38 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1073741816:1073741816
2024/07/01 15:50:38 [notice] 1#1: start worker processes
2024/07/01 15:50:38 [notice] 1#1: start worker process 35
2024/07/01 15:50:38 [notice] 1#1: start worker process 36
^C
```

```sh
kubectl delete hello-web
```

However, this will result in an error because `hello-web` is not a recognized resource type:

```
error: the server doesn't have a resource type "hello-web", it's a pod.
```

The correct command to delete the `hello-web` pod is as follows:

```sh
kubectl delete pod hello-web
```

The output will confirm that the pod was deleted:

```
pod "hello-web" deleted
```

## Busybox

To create a new pod using the configuration in `busybox-0.yaml`, run the following command:

```sh
kubectl apply -f busybox-0.yaml
```

To create multiple pods using the configuration in `busybox-30.yaml`, run the following command:

```sh
kubectl apply -f busybox-30.yaml
```

```
pod/busybox-1 created
pod/busybox-2 created
pod/busybox-3 created
pod/busybox-4 created
...
pod/busybox-29 created
pod/busybox-30 created
```

To view the status of all pods, you can use the `kubectl get pods` command:

```sh
kubectl get pods
```

The output will display the status of all running pods:

```
❯ k get pods
NAME         READY   STATUS    RESTARTS   AGE
boom         1/1     Running   0          17m
busybox-0    1/1     Running   0          5m8s
busybox-1    1/1     Running   0          52s
busybox-10   1/1     Running   0          51s
busybox-11   1/1     Running   0          51s
busybox-12   1/1     Running   0          51s
...
```

To delete all pods with the label `app=busybox`, you can use the `kubectl delete pod -l` command:

```sh
kubectl delete pod -l app=busybox
```

The output will confirm that the pods were deleted:

```
pod "busybox-0" deleted
...
pod "busybox-30" deleted
```

## Pod Selector

### Equality

To create a new pod with the configuration in `pod-selector-equality.yml`, run the following command:

```sh
kubectl apply -f pod-selector-equality.yml
```

The output will confirm that the pod was created:

```
pod/cuda-test created
```

To view detailed information about the `cuda-test` pod, use the following command:

```sh
kubectl describe pod cuda-test
```

```
Name:             cuda-test
Namespace:        default
...
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  51s   default-scheduler  0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```

# Set
To create a new pod with the configuration in `pod-selector-set.yml`, run the following command:

```sh
kubectl apply -f  pod-selector-set.yml
```

The output will confirm that the pod was created:

```
pod/dummy-test created
```

To view the status of all pods, use the following command:

```sh
kubectl get pods
```

The output will display the status of all running pods:

```
NAME         READY   STATUS    RESTARTS        AGE
cuda-test    0/1     Pending   0               3m13s
dummy-test   1/1     Running   0               4m6s
```

```

```
