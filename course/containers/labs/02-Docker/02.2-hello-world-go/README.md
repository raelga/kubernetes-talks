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

## 🌐 Remote Access

For AWS EC2 or remote instances:

```bash
# Get public IP and construct URL
echo "http://$(curl -s ifconfig.me):9999"  # for v1
echo "http://$(curl -s ifconfig.me):8888"  # for v2
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
