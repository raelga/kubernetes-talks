# Hello World in Go with Docker

This lab demonstrates building and running two versions of a Go "Hello World" application using Docker multi-stage builds with security best practices.

## 🎯 Learning Objectives

- Build multi-stage Docker images for Go applications
- Implement security best practices (non-root users, pinned base images)
- Compare different application versions
- Use health check endpoints for container monitoring

## 🧪 Prerequisites

- Docker installed and running
- Basic knowledge of Docker commands
- Text editor or IDE

## 🌍 Environment Setup

Set your Docker repository (customize for your Docker Hub account):

```bash
export REPOSITORY=raelga/hello-world-go
```

---

## 📋 Application Versions

| Version | Description | Endpoint Response |
|---------|-------------|-------------------|
| v1 | Basic "Hello World" | `Hello World` |
| v2 | Includes hostname | `Hello World from <hostname>` |

Both versions include:
- Health check endpoint at `/health`
- Request logging
- Non-root container execution

---

## 🛠️ Version 1: Basic Hello World

### Build and Run

```bash
# Build image
docker build -t ${REPOSITORY}:v1 v1

# Run in foreground
docker run --rm -p 9999:9999 ${REPOSITORY}:v1

# Run in background
docker run --rm -d -p 9999:9999 ${REPOSITORY}:v1
```

### Test Endpoints

```bash
# Main endpoint
curl http://localhost:9999

# Health check
curl http://localhost:9999/health
```

---

## 🛠️ Version 2: With Hostname

### Build and Run

```bash
# Build image
docker build -t ${REPOSITORY}:v2 v2

# Run on different host port
docker run --rm -p 8888:9999 ${REPOSITORY}:v2
```

### Test Endpoints

```bash
# Main endpoint (shows hostname)
curl http://localhost:8888

# Health check (shows hostname)
curl http://localhost:8888/health
```

---

## 🔧 Using Makefiles

Each version includes a Makefile for convenience:

```bash
# In v1/ or v2/ directory
make build  # Build the image
make run    # Run in background
make stop   # Stop running containers
```

---

## 🔍 Container Inspection

### View Running Containers
```bash
docker ps
```

### Check Container Logs
```bash
docker logs <container-id>
```

### Inspect Image Details
```bash
docker inspect ${REPOSITORY}:v1
docker inspect ${REPOSITORY}:v2
```

---

## 📤 Pushing Images to Registry

### Docker Hub Push

```bash
# Login to Docker Hub
docker login

# Push both versions
docker push ${REPOSITORY}:v1
docker push ${REPOSITORY}:v2

# Push with latest tag
docker tag ${REPOSITORY}:v2 ${REPOSITORY}:latest
docker push ${REPOSITORY}:latest
```

### Alternative Registry

```bash
# Tag for different registry
docker tag ${REPOSITORY}:v1 your-registry.com/your-namespace/hello-world-go:v1
docker tag ${REPOSITORY}:v2 your-registry.com/your-namespace/hello-world-go:v2

# Push to alternative registry
docker push your-registry.com/your-namespace/hello-world-go:v1
docker push your-registry.com/your-namespace/hello-world-go:v2
```

### Verify Pushed Images

```bash
# Pull and test your pushed image
docker pull ${REPOSITORY}:v1
docker run --rm -p 9999:9999 ${REPOSITORY}:v1
```

---

## 🌐 Remote Access

For AWS EC2 or remote instances:

```bash
# Get public IP and construct URL
echo "http://$(curl -s ifconfig.me):9999"  # for v1
echo "http://$(curl -s ifconfig.me):8888"  # for v2
```

---

## Memory Constraints

Docker uses cgroups under the hood to limit container resources. You can use the `--memory` flag to set memory limits on containers.

### Running with a memory limit

Run the hello-world-go container with a 25MB memory limit:

```bash
docker run --rm --memory=25m -p 9999:9999 ${REPOSITORY}:v1
```

### Checking the cgroup memory limit on the host

Docker creates a cgroup for each container on the host. You can inspect the memory limit set by Docker:

```bash
CONTAINER_ID=$(docker run --rm -d --memory=25m ${REPOSITORY}:v1)
cat /sys/fs/cgroup/memory/docker/${CONTAINER_ID}/memory.limit_in_bytes
```

Expected output:

```
26214400
```

Stop the container:

```bash
docker stop ${CONTAINER_ID}
```

### Testing the memory limit

Run an alpine container with the same memory limit and open a shell:

```bash
docker run --rm -it --memory=25m alpine sh
```

Inside the container, use `dd` to allocate more memory than the limit allows. `dd` copies blocks of data; `bs` sets the block size in bytes and `dd` allocates that much memory as a buffer. Here we set `bs=52428800` (50MB), which exceeds the 25MB container limit:

```bash
dd if=/dev/zero of=/dev/null bs=52428800 count=1
```

The process will be killed when it exceeds the memory limit:

```
Killed
```

You can also do it in a single line:

```bash
docker run --rm --memory=25m alpine dd if=/dev/zero of=/dev/null bs=52428800 count=1
```

### Verifying the OOM kill

Run without `--rm` to inspect the container state after the OOM kill:

```bash
docker run --name oom-test --memory=25m alpine dd if=/dev/zero of=/dev/null bs=52428800 count=1
docker inspect oom-test --format='{{.State.OOMKilled}}'
```

Expected output:

```
true
```

Clean up:

```bash
docker rm oom-test
```

---

## 🔒 Security Features

- **Non-root execution**: Containers run as user `appuser` (UID 1001)
- **Minimal base image**: Uses Alpine Linux for smaller attack surface
- **Pinned versions**: Base images use specific tags, not `latest`
- **Multi-stage builds**: Separates build and runtime environments

---

## 🐛 Troubleshooting

### Port Already in Use
```bash
# Find process using port
lsof -i :9999

# Kill process if needed
kill -9 <PID>
```

### Container Won't Start
```bash
# Check Docker daemon
docker info

# View detailed error logs
docker logs <container-id>
```

### Image Build Fails
```bash
# Clean Docker cache
docker system prune

# Rebuild with no cache
docker build --no-cache -t ${REPOSITORY}:v1 v1
```

### Health Check Not Responding
```bash
# Test health endpoint directly
curl -v http://localhost:9999/health

# Check if container is healthy
docker inspect <container-id> | grep Health -A 10
```

---

## 🧠 Key Learning Points

- **Multi-stage builds** reduce final image size by excluding build tools
- **Port mapping** (`-p host:container`) allows external access
- **Health checks** enable monitoring and orchestration readiness
- **Non-root containers** improve security posture
- **Container logs** help debug application issues
