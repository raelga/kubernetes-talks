# Docker Filesystem Lab: Building Custom Images

> **Learning Objectives:** Understand Docker image layers, filesystem overlays, and build caching through hands-on practice with three progressive examples.

This lab demonstrates how Docker builds images in layers and utilizes the overlay filesystem. You'll build three versions of a "Hello World" container, each progressively more complex, to observe how Docker optimizes builds through layer caching.

## Prerequisites

- Docker installed and running
- Basic understanding of the command line
- Text editor (optional, for viewing Dockerfiles)

## Lab Overview

We'll explore three versions:

- **v1**: Simple echo command
- **v2**: File creation and reading
- **v3**: Multiple file operations (demonstrates layer caching)

---

## Version 1: Simple Echo Command

The `v1/` directory contains our simplest Dockerfile:

```dockerfile
FROM alpine:latest
CMD ["/bin/echo", "Hello World!"]
```

**Key concepts**: Base image selection, command execution

### Building and Running v1

1. **Build the image:**

   ```bash
   docker build v1 -t hello-world:v1
   ```

2. **Run the container:**

   ```bash
   docker run --rm hello-world:v1
   ```

   Expected output: `Hello World!`

3. **Inspect the image (optional):**
   ```bash
   docker inspect hello-world:v1
   ```

---

## Version 2: File Operations

The `v2/` directory introduces file system operations:

```dockerfile
FROM alpine:latest
RUN echo "Hello World from a file!" >/hello.txt
CMD ["/bin/cat", "/hello.txt"]
```

**Key concepts**: RUN vs CMD, filesystem layers, file creation during build

### Building and Running v2

1. **Build the image:**

   ```bash
   docker build v2 -t hello-world:v2
   ```

   Notice the additional build step creating the file:

   ```
   Step 2/3 : RUN echo "Hello World from a file!" >/hello.txt
   ---> Running in cef17cd5107c
   ---> 09bce474ad42  # New layer created
   ```

2. **Run the container:**

   ```bash
   docker run --rm hello-world:v2
   ```

   Output: `Hello World from a file!`

---

## Version 3: Layer Caching Demonstration

The `v3/` directory adds another file operation to demonstrate Docker's layer caching:

```dockerfile
FROM alpine:latest
RUN echo "Hello World from a file!" >/hello.txt
RUN echo "Saving some info for later." >/later.txt
CMD ["/bin/cat", "/hello.txt"]
```

**Key concepts**: Layer reuse, build optimization, cache efficiency

### Building and Running v3

1. **Build the image:**

   ```bash
   docker build v3 -t hello-world:v3
   ```

   **🎯 Key observation** - Notice the cache usage:

   ```
   Step 2/4 : RUN echo "Hello World from a file!" >/hello.txt
   ---> Using cache  # ⭐ Reuses layer from v2 build!
   ---> 09bce474ad42
   Step 3/4 : RUN echo "Saving some info for later." >/later.txt
   ---> Running in ff977df4f23c  # Only this step runs
   ```

2. **Run the container:**

   ```bash
   docker run --rm hello-world:v3
   ```

   Output: `Hello World from a file!`

## Container files versus volumes

Create a file in a container's writable layer, then remove the container:

```bash
docker run --name filesystem-demo hello-world:v3 sh -c 'echo hello > /tmp/note'
docker rm filesystem-demo
docker run --rm hello-world:v3 sh -c 'cat /tmp/note || echo "File is gone"'
```

The new container starts from the image; it does not inherit the removed container's writable layer.

Now store the file in a named volume:

```bash
docker volume create filesystem-demo-data
docker run --rm -v filesystem-demo-data:/data hello-world:v3 sh -c 'echo hello > /data/note'
docker run --rm -v filesystem-demo-data:/data hello-world:v3 cat /data/note
```

The second container reads `hello`: the volume exists independently of either container. Remove this disposable volume when finished:

```bash
docker volume rm filesystem-demo-data
```

---

## Understanding Docker's Overlay Filesystem

Docker uses the overlay2 storage driver to manage image layers efficiently. Each RUN command creates a new layer.

### Exploring the Overlay Filesystem

**⚠️ Note**: This requires root access and may vary by Docker installation.

1. **Navigate to Docker's storage directory:**

   ```bash
   cd /var/lib/docker/
   ```

2. **Examine the overlay2 structure:**

   ```bash
   sudo tree /var/lib/docker/overlay2/ -L 2
   ```

   You'll see directories like:

   ```
   /var/lib/docker/overlay2/
   ├── [layer-id-1]/
   │   ├── diff/           # Changes in this layer
   │   │   └── hello.txt   # File from v2 build
   │   ├── link
   │   ├── lower           # References to lower layers
   │   └── work
   ├── [layer-id-2]/
   │   ├── diff/
   │   │   └── later.txt   # File from v3 build
   │   ├── link
   │   ├── lower
   │   └── work
   ```

### Understanding Layer Efficiency

- **v1**: Uses only the Alpine base layer
- **v2**: Adds one layer with `hello.txt`
- **v3**: Reuses v2's layer + adds new layer with `later.txt`

## Key Takeaways

✅ **Layer Caching**: Docker reuses identical layers across builds
✅ **Build Optimization**: Order Dockerfile instructions for maximum cache efficiency
✅ **Storage Efficiency**: Shared layers reduce disk usage
✅ **Overlay Filesystem**: Union filesystem enables efficient layer management

## Next Steps

- Experiment with changing the order of RUN commands
- Try building with `--no-cache` flag to see the difference
- Explore `docker history <image>` to examine layer sizes
- Use `docker system df` to see space usage by images and layers

## Cleanup

The examples use `--rm` to remove their containers when they exit. Remove only
the images built for this lab:

```bash
docker rmi hello-world:v1 hello-world:v2 hello-world:v3
```

If you previously ran a container without `--rm`, identify it with
`docker ps -a` and remove that specific container with `docker rm <container-id>`
before removing its image. Shared build cache and unrelated Docker resources are
left untouched.
