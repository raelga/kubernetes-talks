# Hello World NGINX with Docker

This lab walks you through building, running, and managing a custom NGINX container image using Docker.

---

## 🧪 Prerequisites

Make sure Docker is installed and the Docker daemon is running.

---

## 🌍 Set Up Your Environment

Set your image tag and repository (change the repository if needed):

```bash
export TAG=v1
export REPOSITORY=raelga/hello-world-nginx
```

## 🔨 Build the Container Image

Build the Docker image using the provided Dockerfile:

```
docker build -t ${REPOSITORY}:${TAG} -f Dockerfile ctx
```

## 🚀 Run the Container

### ▶️ Foreground (attached mode)

```bash
docker run --rm -p 8080:8080 ${REPOSITORY}:${TAG}
```

### 🔄 Background (detached mode)

```bash
docker run --name hello --rm -d -p 8080:8080 ${REPOSITORY}:${TAG}
```

Open your browser and navigate to: http://localhost:8080

If it's running in an AWS EC2 instance, use:

```bash
echo http://$(curl -sq ifconfig.me):8080
```

## 📜 View Container Logs

Tail the logs in real-time:

```
docker logs -f hello
```

### 🐚 Access the Container Shell

Spawn an interactive shell inside the running container:

```
docker exec -ti hello /bin/sh
```

## ☁️ Push the Container to Docker Hub

### 🌐 Create a Docker Hub account

https://app.docker.com/signup

### 🔐 Login to Docker Hub

First loging into dockerhub with:

```
docker login
```

# 📤 Push the Image

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

Check your published image:

```bash
echo https://hub.docker.com/r/${REPOSITORY}
```
