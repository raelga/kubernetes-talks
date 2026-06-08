# StatefulSet

A **StatefulSet** manages Pods that need a **stable identity** and **persistent per-Pod storage** — databases, message brokers, and other clustered, stateful apps. Compared to a Deployment, a StatefulSet gives each Pod:

- A **stable name**: `mysql-0`, `mysql-1`, … (not a random hash).
- A **stable network identity** via a headless Service: `mysql-0.mysql`.
- Its **own PersistentVolumeClaim**, created from a `volumeClaimTemplate`, that survives Pod rescheduling.
- **Ordered** creation, scaling, and deletion.

This lab deploys MySQL as a StatefulSet.

## Prerequisites

A default `StorageClass` for dynamic provisioning. Kind ships with one named `standard` already set as default — verify with:

```sh
kubectl get storageclass
```

```
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  10m
```

> On clusters where the default class has a different name (e.g. `gp2` on EKS), mark it default with:
> `kubectl patch storageclass <name> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`

## Deploy MySQL

The credentials live in a Secret; the StatefulSet and its headless Service are in `mysql-sts.yaml`:

```sh
kubectl apply -f mysql-credentials-secret.yaml -f mysql-sts.yaml
kubectl rollout status statefulset/mysql
```

```
secret/mysql-credentials created
service/mysql created
statefulset.apps/mysql created
partitioned roll out complete: 1 new pods have been updated...
```

The Pod is named `mysql-0` (ordinal index), and the Service is **headless** (`CLUSTER-IP: None`), which is what gives each Pod a stable DNS name:

```sh
kubectl get statefulset,pod,svc -l app=mysql
```

```
NAME                     READY   AGE
statefulset.apps/mysql   1/1     14s

NAME          READY   STATUS    RESTARTS   AGE
pod/mysql-0   1/1     Running   0          14s

NAME            TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
service/mysql   ClusterIP   None         <none>        3306/TCP   14s
```

## Per-Pod persistent storage

The `volumeClaimTemplate` named `volume` produces a PVC per Pod, named `<template>-<pod>` → `volume-mysql-0`:

```sh
kubectl get pvc -l app=mysql
```

```
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
volume-mysql-0   Bound    pvc-ffa5482e-5d96-435b-96ce-fd7893daac4b   1Gi        RWO            standard       14s
```

## Connect to the database

Once MySQL finishes initialising (give it ~20–30s after the Pod is Ready), connect with the MySQL client inside the Pod. The root password comes from the Secret (`admin`):

```sh
kubectl exec -it mysql-0 -- mysql -uroot -padmin -e "SHOW DATABASES;"
```

```
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| wordpress          |
+--------------------+
```

> The `wordpress` database was created automatically from the `MYSQL_DATABASE` env var.
> You can also debug a running Pod without a shell using an ephemeral container:
> `kubectl debug -it pod/mysql-0 --image=mysql:8 -- mysql -h127.0.0.1 -padmin`

## Stable identity survives rescheduling

Delete the Pod — the StatefulSet recreates it with the **same name** and **reattaches the same PVC** (data is preserved):

```sh
kubectl delete pod mysql-0
kubectl rollout status statefulset/mysql
kubectl get pvc -l app=mysql
```

```
pod "mysql-0" deleted
partitioned roll out complete: 1 new pods have been updated...
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
volume-mysql-0   Bound    pvc-ffa5482e-5d96-435b-96ce-fd7893daac4b   1Gi        RWO            standard       60s
```

The PVC (`pvc-ffa5482e…`) is unchanged — a Deployment with shared/ephemeral storage could not guarantee this.

### Cleanup

Deleting the StatefulSet does **not** delete its PVCs (by design, to protect data). Remove them explicitly:

```sh
kubectl delete -f mysql-sts.yaml -f mysql-credentials-secret.yaml
kubectl delete pvc -l app=mysql
```
