# Jobs & CronJobs

A **Job** runs one or more Pods to **completion** and ensures a specified number of them succeed. Unlike Deployments (which keep Pods running forever), a Job is for batch work that finishes: a migration, a backup, a computation. A **CronJob** creates Jobs on a repeating schedule.

## Job with multiple completions

`job-5.yaml` requests `completions: 5`. With no `parallelism` set, the Job runs the Pods **one at a time** until 5 have succeeded. Each Pod prints its job name (via the Downward API), hostname, and timestamp.

```sh
kubectl apply -f job-5.yaml
```

```
job.batch/hello-5 created
```

Watch it progress. Because completions run sequentially and each pulls the `ubuntu:trusty` image, the Job takes a couple of minutes to reach 5/5:

```sh
kubectl get jobs
```

```
NAME      STATUS    COMPLETIONS   DURATION   AGE
hello-5   Running   4/5           2m         2m
```

The Pods stay around as `Completed` so you can read their logs:

```sh
kubectl get pods -l app=hello
```

```
NAME            READY   STATUS      RESTARTS   AGE
hello-5-dbdd2   0/1     Completed   0          29s
hello-5-jxhbv   0/1     Completed   0          2m
hello-5-ml7sf   0/1     Completed   0          80s
hello-5-w4rl8   0/1     Completed   0          54s
```

Wait for the Job to finish and read one Pod's output:

```sh
kubectl wait --for=condition=complete job/hello-5 --timeout=300s
kubectl logs -l app=hello --tail=1
```

```
Hello, I was created by the Job hello-5 and ran in hello-5-jxhbv at Mon Jun  8 16:23:36 UTC 2026.
```

## generateName: `create` vs `apply`

`job-manual.yaml` uses `generateName` instead of a fixed `name`, so the API server appends a random suffix on creation. This is **incompatible with `kubectl apply`**, which needs a stable name to track the object:

```sh
kubectl apply -f job-manual.yaml
```

```
error: from hello-5-: cannot use generate name with apply
```

Use `kubectl create` instead — each invocation produces a uniquely named Job:

```sh
kubectl create -f job-manual.yaml
kubectl create -f job-manual.yaml
```

```
job.batch/hello-5-c9gnz created
job.batch/hello-5-q4m7t created
```

## CronJob

`cronjob.yaml` schedules a Job every minute (`* * * * *`):

```sh
kubectl apply -f cronjob.yaml
kubectl get cronjob hello
```

```
NAME    SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
hello   * * * * *   False     0        <none>          5s
```

After a minute or two it starts spawning Jobs automatically:

```sh
kubectl get jobs -l app=hello
```

```
NAME             STATUS     COMPLETIONS   DURATION   AGE
hello-29...      Complete   1/1           4s         2m
hello-29...      Complete   1/1           5s         1m
```

Common schedule expressions:

| Schedule | Meaning |
|----------|---------|
| `*/5 * * * *` | Every 5 minutes |
| `0 */6 * * *` | Every 6 hours |
| `0 9 * * MON` | Every Monday at 09:00 |

### Cleanup

```sh
kubectl delete cronjob hello
kubectl delete jobs -l app=hello
```
