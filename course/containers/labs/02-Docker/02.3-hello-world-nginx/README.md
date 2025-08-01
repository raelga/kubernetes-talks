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

```bash
docker build -t ${REPOSITORY}:${TAG} -f Dockerfile ctx
```

Alternatively, use the provided Makefile:

```bash
make build
```

## 🚀 Run the Container

### ▶️ Foreground (attached mode)

```bash
docker run --rm -p 8080:8080 ${REPOSITORY}:${TAG}
```

Or using the Makefile:

```bash
make run
```

### 🔄 Background (detached mode)

```bash
docker run --name hello --rm -d -p 8080:8080 ${REPOSITORY}:${TAG}
```

Or using the Makefile:

```bash
make bg
```

### 🌐 Access the Application

Open your browser and navigate to: http://localhost:8080

If running on a remote server (like AWS EC2), get the public URL:

```bash
echo http://$(curl -sq ifconfig.me):8080
```

## 📜 View Container Logs

Tail the logs in real-time:

```bash
docker logs -f hello
```

Or using the Makefile:

```bash
make logs
```

### 🐚 Access the Container Shell

Spawn an interactive shell inside the running container:

```bash
docker exec -ti hello /bin/sh
```

Or using the Makefile:

```bash
make exec
```

## ☁️ Push the Container to Docker Hub

### 🌐 Create a Docker Hub account

https://app.docker.com/signup

### 🔐 Login to Docker Hub

First login to Docker Hub with:

```bash
docker login
```

### 📤 Push the Image

Push the image to the Docker Hub registry:

```bash
docker push ${REPOSITORY}:${TAG}
```

Or using the Makefile:

```bash
make push
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

## 🧹 Cleanup

### Stop and Remove the Container

If running in background mode:

```bash
docker stop hello
```

Or using the Makefile:

```bash
make clean
```

### Remove the Image

To remove the locally built image:

```bash
docker rmi ${REPOSITORY}:${TAG}
```

## 🔍 Verification

After each step, you can verify your progress:

1. **Check if image was built:**
   ```bash
   docker images | grep ${REPOSITORY}
   ```

2. **Check if container is running:**
   ```bash
   docker ps | grep hello
   ```

3. **Test the application:**
   ```bash
   curl http://localhost:8080
   ```

## 🛠️ Troubleshooting

### Port Already in Use

If you get a "port already in use" error:

```bash
# Find what's using port 8080
lsof -i :8080

# Or use a different port
docker run --rm -p 8081:8080 ${REPOSITORY}:${TAG}
```

### Permission Denied

If you get permission errors with Docker:

```bash
# Add your user to the docker group (Linux)
sudo usermod -aG docker $USER

# Then restart your session or run:
newgrp docker
```

### Image Not Found

If the image is not found when pushing:

```bash
# Make sure you're logged in
docker login

# Check your image name matches your Docker Hub username
docker images | grep ${REPOSITORY}
```
