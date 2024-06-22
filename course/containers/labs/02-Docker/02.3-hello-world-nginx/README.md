# Hello World NGINX

## Build the container

Export some environment variables

```
export TAG=v1
export REPOSITORY=raelga/hello-world-nginx
```

Build the container image:

```
docker build -t ${REPOSITORY}:${TAG} -f Dockerfile ctx
```

## Run the container

Run the container and attach your terminal:

```
docker build -t ${REPOSITORY}:${TAG} -f Dockerfile ctx
```

Run the container in the background:

```
docker run --name hello --rm -d -p 8080:8080 ${REPOSITORY}:${TAG}
```

## View the containers logs

```
docker logs -f hello
```

## Spawn a shell into the containr

```
docker exec -ti hello /bin/sh
```

## Push the container

First loging into dockerhub with:

```
docker login
````

And push it to the Docker Hub registry:

```
docker push ${REPOSITORY}:${TAG}
```

```
The push refers to repository [docker.io/raelga/hello-world-nginx]
7f101be3a26a: Pushed
4fc64b45292c: Pushed
96f80c66bc08: Pushed
bdea7c663e86: Mounted from nginxdemos/hello-world-nginx
1b22827e15b4: Mounted from nginxdemos/hello-world-nginx
d9f50eaf56fa:
 Mounted from nginxdemos/hello-world-nginx
2530717ff0bb: Mounted from nginxdemos/hello-world-nginx
e7766bc830a8: Mounted from nginxdemos/hello-world-nginx
cb411529b86f: Mounted from nginxdemos/hello-world-nginx
bc09720137db: Mounted from nginxdemos/hello-world-nginx
3dab9f8bf2d2: Mounted from nginxdemos/hello-world-nginx
v1: digest: sha256:092132a73bd3587ec5a82cb598236046023e1aa06b6e29db845dfd0b9b6e4acd size: 2611
```
