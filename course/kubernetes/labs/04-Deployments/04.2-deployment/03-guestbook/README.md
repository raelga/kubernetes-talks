## Guestbook Example

This example shows how to build a simple multi-tier web application using Kubernetes and Docker. The application consists of a web front end, Redis master for storage, and replicated set of Redis slaves, all for which we will create Kubernetes replication controllers, pods, and services.

![Guestbook](guestbook-page.png)

### Docker login

Login following instructions provided by 

```
https://hub.docker.com/settings/security?generateToken=true
```

(TODO: Use ECR as example.)

Export your information

```bash
export DOCKER_REGISTRY=$(docker info | sed '/Username:/!d;s/.* //') \
  && echo ${DOCKER_REGISTRY}
```

That command should output your docker registry username.

### Build v1

```bash
docker build -t ${DOCKER_REGISTRY}/guestbook:v1 app-v1/
```

Expected output:

```
[+] Building 0.2s (15/15) FINISHED                                                                                                 docker:default
 => [internal] load build definition from Dockerfile                                                                                         0.0s
 => => transferring dockerfile: 1.10kB                                                                                                       0.0s
 => [internal] load .dockerignore                                                                                                            0.0s
 => => transferring context: 2B                                                                                                              0.0s
 => [internal] load metadata for docker.io/library/golang:1.13.0
...
 => => exporting layers                                                                                                                      0.0s
 => => writing image sha256:73ed06d9ca85437d08c0d27c3d9306ceb93958986e0137f5a8cdc93b189b9b2a                                                 0.0s
 => => naming to docker.io/raelga/guestbook:v1     
```

### Push v1

```bash
docker push ${DOCKER_REGISTRY}/guestbook:v1
```

Expected output:

```
The push refers to repository [docker.io/raelga/guestbook]
285eb246fb9c: Pushed 
662817c57e6a: Pushed 
6cbd6604b9ef: Pushed 
a2a732fe6097: Pushed 
4a0c5f6def4b: Pushed 
v1: digest: sha256:6e008bd2a566278a803721362691ea8e589a0006ae32c2de878a170371a914d1 size: 1355
```

### Deploy v1

```bash
k apply -f k8s/
```

Expected output:

```
deployment.apps/guestbook created
service/guestbook created
deployment.apps/redis-master created
service/redis-master created
deployment.apps/redis-slave created
service/redis-slave created
```

### Connect to your app

```bash
kubectl get svc guestbook -w
```

Expected output:

```
NAME        TYPE           CLUSTER-IP     EXTERNAL-IP                                                              PORT(S)        AGE
guestbook   LoadBalancer   172.20.3.246   afec1c087c929423993d5441aae45ad1-743693504.us-east-1.elb.amazonaws.com   80:30267/TCP   2m1s
```

---

### Build v2

```bash
docker build -t ${DOCKER_REGISTRY}/guestbook:v2 app-v2/
```

Expected output:

```
[+] Building 0.4s (16/16) FINISHED                                                                                                 docker:default
...
 => CACHED [stage-1 2/5] COPY --from=0 /app/main .                                                                                           0.0s
 => [stage-1 3/5] COPY ./public/index.html public/index.html                                                                                 0.0s
 => [stage-1 4/5] COPY ./public/script.js public/script.js                                                                                   0.0s
 => [stage-1 5/5] COPY ./public/style.css public/style.css                                                                                   0.0s
 => exporting to image                                                                                                                       0.0s
 => => exporting layers                                                                                                                      0.0s
 => => writing image sha256:543f779b7c4709308d38aab7f69793fa6612973e3191cdfeb37b61f335fe24d8                                                 0.0s
 => => naming to docker.io/raelga/guestbook:v2 
```

### Check changes when deploying v2

```bash
k diff -f k8s-v2/
```

Expected output:

```
diff -u -N /tmp/LIVE-3458226790/apps.v1.Deployment.default.guestbook /tmp/MERGED-2554596360/apps.v1.Deployment.default.guestbook
--- /tmp/LIVE-3458226790/apps.v1.Deployment.default.guestbook   2024-02-12 16:30:55.499115401 +0000
+++ /tmp/MERGED-2554596360/apps.v1.Deployment.default.guestbook 2024-02-12 16:30:55.499115401 +0000
@@ -6,7 +6,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"labels":{"app":"guestbook"},"name":"guestbook","namespace":"default"},"spec":{"replicas":5,"selector":{"matchLabels":{"app":"guestbook"}},"strategy":{"rollingUpdate":{"maxSurge":2,"maxUnavailable":1},"type":"RollingUpdate"},"template":{"metadata":{"labels":{"app":"guestbook"}},"spec":{"containers":[{"image":"raelga/guestbook:v1","name":"guestbook","ports":[{"containerPort":3000,"name":"http-server"}],"resources":{"limits":{"cpu":"50m","memory":"128M"},"requests":{"cpu":"50m","memory":"128M"}}}]}}}}
   creationTimestamp: "2024-02-12T16:22:20Z"
-  generation: 1
+  generation: 2
   labels:
     app: guestbook
   name: guestbook
@@ -32,7 +32,7 @@
         app: guestbook
     spec:
       containers:
-      - image: raelga/guestbook:v1
+      - image: raelga/guestbook:v2
         imagePullPolicy: IfNotPresent
         name: guestbook
         ports:
```

### Deploy v2

```
k apply -f k8s-v2/
```

Or

```
kubectl set image deployment/guestbook guestbook=${DOCKER_REGISTRY}/guestbook:v2
```

### Check app

```bash
kubectl get svc guestbook
```

Expected output:

```
NAME        TYPE           CLUSTER-IP     EXTERNAL-IP                                                              PORT(S)        AGE
guestbook   LoadBalancer   172.20.3.246   afec1c087c929423993d5441aae45ad1-743693504.us-east-1.elb.amazonaws.com   80:30267/TCP   2m1s
```

### Check pods

```
kubectl get pods -l app=guestbook -w
```

You can leave that command in the background

### Push v2

```bash
docker push ${DOCKER_REGISTRY}/guestbook:v2
```

Expected output:

```
The push refers to repository [docker.io/raelga/guestbook]
1c27304d8209: Pushed 
285eb246fb9c: Layer already exists 
662817c57e6a: Layer already exists 
6cbd6604b9ef: Layer already exists 
a2a732fe6097: Layer already exists 
4a0c5f6def4b: Layer already exists 
v2: digest: sha256:496c7f9ce3cce04324b3d8ac612eafda02668013b6e829c489c4ebd65ee35ce2 size: 1564
```

### Recheck pods

### Check app

```bash
kubectl get svc guestbook
```

Expected output:

```
NAME        TYPE           CLUSTER-IP     EXTERNAL-IP                                                              PORT(S)        AGE
guestbook   LoadBalancer   172.20.3.246   afec1c087c929423993d5441aae45ad1-743693504.us-east-1.elb.amazonaws.com   80:30267/TCP   2m1s
```

### Rollback

```bash
kubectl rollout undo deployment/guestbook
```

Expected output:

```
deployment.apps/guestbook rolled back
```

### Build v3

```bash
docker build -t ${DOCKER_REGISTRY}/guestbook:v3 app-v3/
```

Expected output:


```
[+] Building 0.2s (16/16) FINISHED                                                                                                 docker:default
 => [internal] load build definition from Dockerfile                                                                                         0.0s
 => => transferring dockerfile: 1.13kB                                                                                                       0.0s
 => [internal] load .dockerignore                                                                                                            0.0s
 => => transferring context: 2B                                                                                                              0.0s
 => [internal] load metadata for docker.io/library/golang:1.13.0                                                                             0.1s
 => [internal] load build context                                                                                                            0.0s
 => => transferring context: 17.27kB                                                                                                         0.0s
 => [stage-0 1/5] FROM docker.io/library/golang:1.13.0@sha256:90d554b5ae59cb63d2bf42bdfcd60aa1feb4794d9e3a9cbb9d2deb477c088be0               0.0s
 => [stage-1 1/6] WORKDIR /app                                                                                                               0.0s
 => CACHED [stage-0 2/5] RUN go get github.com/codegangsta/negroni   github.com/gorilla/mux   github.com/xyproto/simpleredis/v2              0.0s
 => CACHED [stage-0 3/5] WORKDIR /app                                                                                                        0.0s
 => CACHED [stage-0 4/5] ADD ./main.go .                                                                                                     0.0s
 => CACHED [stage-0 5/5] RUN CGO_ENABLED=0 GOOS=linux go build -o main .                                                                     0.0s
 => CACHED [stage-1 2/6] COPY --from=0 /app/main .                                                                                           0.0s
 => CACHED [stage-1 3/6] COPY ./public/index.html public/index.html                                                                          0.0s
 => CACHED [stage-1 4/6] COPY ./public/script.js public/script.js                                                                            0.0s
 => CACHED [stage-1 5/6] COPY ./public/style.css public/style.css                                                                            0.0s
 => [stage-1 6/6] COPY ./public/upc.png public/upc.png                                                                                       0.0s
 => exporting to image                                                                                                                       0.0s
 => => exporting layers                                                                                                                      0.0s
 => => writing image sha256:8631f3f72b52c6a8e4a1ac8a136e1b5a76fe3b6b4d30e821b913f51ec8d211fe                                                 0.0s
 => => naming to docker.io/raelga/guestbook:v3    
 ```

### Push v3

```
docker push ${DOCKER_REGISTRY}/guestbook:v3
```

Expected output:

```
The push refers to repository [docker.io/raelga/guestbook]
4f41d8dca795: Pushed 
e5ec8980d978: Pushed 
433fe715d00d: Pushed 
40017a79c50b: Pushed 
ed9d0dc8e173: Pushed 
f0e6fcbe691a: Pushed 
v3: digest: sha256:e542bc423428950660d1c678793183e0fdd98cee5e4ea02049a466d43d8b9da2 size: 1564
```

## Deploy v3

```
kubectl set image deployment/guestbook guestbook=${DOCKER_REGISTRY}/guestbook:v3
```

### Check app

```bash
kubectl get svc guestbook
```

Expected output:

```
NAME        TYPE           CLUSTER-IP     EXTERNAL-IP                                                              PORT(S)        AGE
guestbook   LoadBalancer   172.20.3.246   afec1c087c929423993d5441aae45ad1-743693504.us-east-1.elb.amazonaws.com   80:30267/TCP   2m1s
```

## Cleanup

```
kubectl delete -f k8s
```

Expected output:

```
deployment.apps "guestbook" deleted
service "guestbook" deleted
deployment.apps "redis-master" deleted
service "redis-master" deleted
deployment.apps "redis-slave" deleted
service "redis-slave" deleted
```