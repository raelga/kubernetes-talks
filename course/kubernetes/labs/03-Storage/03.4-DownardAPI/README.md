# Downward API Storage Examples

## Create the shell pod

This command applies the configuration from the `shell.yaml` file to create a pod.

```sh
kubectl apply -f shell.yaml
```

## Attach to the pod and review the volumes and env variables

This command allows you to execute a bash shell inside the `shell-api` pod.
Once inside, you can review the volumes.

```sh
kubectl exec -ti shell-api -- /bin/bash
```

Using the `env` command to list the environment variables:

```sh
kubectl exec -ti shell-api -- env | grep MY_POD
```

```
MY_POD_NAME=shell-api
MY_POD_NAMESPACE=default
MY_POD_IP=10.244.0.58
```

And with `find` inspect the volumes:

```sh
kubectl exec -ti shell-api -- find /etc/api-info/
```

```
/etc/api-info/
/etc/api-info/..2024_07_04_10_21_30.821344630
/etc/api-info/..2024_07_04_10_21_30.821344630/labels
/etc/api-info/..2024_07_04_10_21_30.821344630/annotations
/etc/api-info/..data
/etc/api-info/labels
/etc/api-info/annotations
```

And with `cat` read the content of the files:

```sh
kubectl exec -ti shell-api -- cat /etc/api-info/annotations
```

```

build="v1.0.1"
builder="rael"
kubectl.kubernetes.io/last-applied-configuration="{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{\"build\":\"v1.0.1\",\"builder\":\"rael\"},\"labels\":{\"app\":\"shell\"},\"name\":\"shell-api\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"command\":[\"bash\",\"-c\",\"sleep 3600\"],\"env\":[{\"name\":\"MY_POD_NAME\",\"valueFrom\":{\"fieldRef\":{\"fieldPath\":\"metadata.name\"}}},{\"name\":\"MY_POD_NAMESPACE\",\"valueFrom\":{\"fieldRef\":{\"fieldPath\":\"metadata.namespace\"}}},{\"name\":\"MY_POD_IP\",\"valueFrom\":{\"fieldRef\":{\"fieldPath\":\"status.podIP\"}}}],\"image\":\"raelga/toolbox\",\"name\":\"shell\",\"volumeMounts\":[{\"mountPath\":\"/etc/api-info\",\"name\":\"podinfo\",\"readOnly\":false}]}],\"volumes\":[{\"downwardAPI\":{\"items\":[{\"fieldRef\":{\"fieldPath\":\"metadata.labels\"},\"path\":\"labels\"},{\"fieldRef\":{\"fieldPath\":\"metadata.annotations\"},\"path\":\"annotations\"}]},\"name\":\"podinfo\"}]}}\n"
kubernetes.io/config.seen="2024-07-04T10:21:30.768408976Z"
kubernetes.io/config.source="api"%

```

```

```
