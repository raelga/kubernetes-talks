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

### 🌐 Advanced Networking Examples

Explore different networking options for containers:

```bash
# Run with host networking (container shares host's network stack)
docker run --name hello-host --rm -d --network host ${REPOSITORY}:${TAG}

# Run with custom port mapping
docker run --name hello-custom --rm -d -p 9090:8080 ${REPOSITORY}:${TAG}

# Run with multiple port mappings
docker run --name hello-multi --rm -d -p 8080:8080 -p 8443:443 ${REPOSITORY}:${TAG}

# Run with specific IP binding
docker run --name hello-ip --rm -d -p 127.0.0.1:8080:8080 ${REPOSITORY}:${TAG}

# Create a custom network
docker network create nginx-network

# Run container in custom network
docker run --name hello-network --rm -d --network nginx-network -p 8080:8080 ${REPOSITORY}:${TAG}

# Connect running container to additional network
docker network connect bridge hello-network

# Inspect network details
docker network inspect nginx-network

# List all networks
docker network ls
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

## 📊 Container Management & Monitoring

Advanced container management and monitoring commands:

### 📈 Container Statistics
```bash
# Real-time container statistics
docker stats hello

# One-time stats for all containers
docker stats --no-stream

# Stats with custom format
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
```

### 🔍 Container Inspection
```bash
# Get detailed container information
docker inspect hello

# Get specific information using Go templates
docker inspect hello --format='{{.State.Status}}'
docker inspect hello --format='{{.NetworkSettings.IPAddress}}'
docker inspect hello --format='{{.Config.Image}}'

# Get container processes
docker top hello

# Get container port mappings
docker port hello
```

### 📋 Container Listing
```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# List containers with custom format
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# List container IDs only
docker ps -q

# Filter containers
docker ps --filter "name=hello"
docker ps --filter "status=running"
```

### ⏯️ Container Lifecycle Management
```bash
# Pause/unpause a container
docker pause hello
docker unpause hello

# Restart a container
docker restart hello

# Rename a container
docker rename hello nginx-hello

# Update container resources
docker update --memory="256m" --cpus="0.5" hello
```

### 📁 Container File Operations
```bash
# Copy files from container to host
docker cp hello:/etc/nginx/nginx.conf ./nginx.conf

# Copy files from host to container
docker cp ./custom.html hello:/usr/share/nginx/html/

# Create a new image from container changes
docker commit hello ${REPOSITORY}:modified
```

### 💾 Volume and Data Management

Work with Docker volumes and bind mounts:

```bash
# Create a named volume
docker volume create nginx-data

# Run container with named volume
docker run --name hello-volume --rm -d -p 8080:8080 \
  -v nginx-data:/usr/share/nginx/html ${REPOSITORY}:${TAG}

# Run container with bind mount (mount host directory)
docker run --name hello-bind --rm -d -p 8080:8080 \
  -v $(pwd)/html:/usr/share/nginx/html ${REPOSITORY}:${TAG}

# Run container with read-only volume
docker run --name hello-readonly --rm -d -p 8080:8080 \
  -v $(pwd)/html:/usr/share/nginx/html:ro ${REPOSITORY}:${TAG}

# Run container with temporary filesystem (tmpfs)
docker run --name hello-tmpfs --rm -d -p 8080:8080 \
  --tmpfs /tmp ${REPOSITORY}:${TAG}

# List all volumes
docker volume ls

# Inspect volume details
docker volume inspect nginx-data

# Remove unused volumes
docker volume prune

# Remove specific volume
docker volume rm nginx-data
```

### 🔧 Environment Variables and Configuration

Pass configuration to containers:

```bash
# Run with environment variables
docker run --name hello-env --rm -d -p 8080:8080 \
  -e NGINX_HOST=localhost \
  -e NGINX_PORT=8080 \
  ${REPOSITORY}:${TAG}

# Run with environment file
echo "NGINX_HOST=localhost" > .env
echo "NGINX_PORT=8080" >> .env
docker run --name hello-envfile --rm -d -p 8080:8080 \
  --env-file .env ${REPOSITORY}:${TAG}

# Run with custom working directory
docker run --name hello-workdir --rm -d -p 8080:8080 \
  -w /usr/share/nginx/html ${REPOSITORY}:${TAG}

# Run with custom user
docker run --name hello-user --rm -d -p 8080:8080 \
  --user nginx ${REPOSITORY}:${TAG}

# Run with resource limits
docker run --name hello-limits --rm -d -p 8080:8080 \
  --memory="128m" \
  --cpus="0.5" \
  --restart=unless-stopped \
  ${REPOSITORY}:${TAG}
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

## ⚙️ Docker System Management

System-level Docker commands for resource management:

### 🧹 System Cleanup
```bash
# Remove all stopped containers
docker container prune

# Remove all unused images
docker image prune

# Remove all unused networks
docker network prune

# Remove all unused volumes
docker volume prune

# Remove everything unused (containers, networks, images, build cache)
docker system prune

# Aggressive cleanup (includes unused images, even with tags)
docker system prune -a
```

### 📊 System Information
```bash
# Display system-wide information
docker system df

# Show detailed space usage
docker system df -v

# Docker system info
docker info

# Docker version information
docker version
```

### 🔍 System Events
```bash
# Show real-time events from the Docker daemon
docker events

# Filter events by container
docker events --filter container=hello

# Filter events by type
docker events --filter type=container
```

## 🔍 Docker Image Inspection

Explore and inspect your Docker images:

### 📊 List All Images
```bash
# List all images
docker images

# List images with specific repository
docker images ${REPOSITORY}

# List images with size and creation date
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
```

### 🔍 Inspect Image Details
```bash
# Get detailed information about the image
docker inspect ${REPOSITORY}:${TAG}

# Get image history (layers)
docker history ${REPOSITORY}:${TAG}

# Get image configuration in JSON format
docker inspect ${REPOSITORY}:${TAG} --format='{{json .Config}}' | jq .
```

### 📏 Check Image Size
```bash
# Show image size
docker images ${REPOSITORY}:${TAG} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Analyze image layers and their sizes
docker history ${REPOSITORY}:${TAG} --format "table {{.CreatedBy}}\t{{.Size}}"
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
