# Hello World in GoLang with Docker

This lab guides you through building and running two versions of a simple Go-based "Hello World" application using Docker.

## 🧪 Prerequisites

Ensure Docker is installed and running on your system.

## 🌍 Set Up Your Environment

Set your Docker image repository (adjust to your own Docker Hub account if necessary):

```bash
export REPOSITORY=raelga/hello-world-go
```

---

## 🛠️ Build and Run v1 Container

### 🔨 Build v1 Image

```bash
docker build -t ${REPOSITORY}:v1 v1
```

### 🚀 Run v1 Container (Foreground)

```bash
docker run --rm -p 9999:9999 ${REPOSITORY}:v1
```

### 🧾 Run v1 Container (Detached)

```bash
docker run --rm -d -p 9999:9999 ${REPOSITORY}:v1
```

Access the app at: [http://localhost:9999](http://localhost:9999)

If it's running in an AWS EC2 instance, use:

```bash
echo http://$(curl -sq ifconfig.me):9999
```

---

## 🛠️ Build and Run v2 Container

### 🔨 Build v2 Image

```bash
docker build -t ${REPOSITORY}:v2 v2
```

### 🚀 Run v2 Container

```bash
docker run --rm -p 8888:9999 ${REPOSITORY}:v2
```

Access the v2 app at: [http://localhost:8888](http://localhost:8888)

If it's running in an AWS EC2 instance, use:

```bash
echo http://$(curl -sq ifconfig.me):8888
```

---

## 🧠 Additional Notes

- The containers run basic Go servers returning different responses.
- The port mapping `-p <host>:<container>` maps your local machine port to the container's port.
- You can inspect the network namespace behavior with tools like `docker network inspect` and `ip netns`.
