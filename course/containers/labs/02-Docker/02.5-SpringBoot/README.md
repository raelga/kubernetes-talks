# Spring Boot DreamRoute with Docker

This lab walks you through building, running, and managing a Spring Boot application container image using Docker.

---

## 🧪 Prerequisites

Make sure Docker is installed and the Docker daemon is running.

```
 git clone https://github.com/Femcoders-Travellers/DreamRoute.git src
```

### 🔐 Docker Hub Setup

1. **Create a Docker Hub account** (if you don't have one):

   https://app.docker.com/signup

2. **Login to Docker Hub**:

   ```bash
   docker login
   ```

   Enter your Docker Hub username and token when prompted.

---

### 1. Project Structure

The project contains a complete Spring Boot application with the following structure:

- `src/` - Spring Boot application source code
- `Dockerfile` - Multi-stage Docker build configuration
- `src/pom.xml` - Maven project configuration

## 🌍 Set Up Your Environment

Set your image tag and repository (change the repository if needed):

```bash
export TAG=v1
export REPOSITORY=raelga/springboot
```

## 🔨 Build the Container Image

Build the Docker image using the provided Dockerfile:

```bash
docker build -t ${REPOSITORY}:${TAG} .
```

## 🚀 Run the Container

### ▶️ Foreground (attached mode)

```bash
docker run --rm -p 8080:8080 ${REPOSITORY}:${TAG}
```

### 🔄 Background (detached mode)

```bash
docker run --name dreamroute --rm -d -p 8080:8080 ${REPOSITORY}:${TAG}
```

### 🌐 Advanced Networking Examples

Explore different networking options for containers:

```bash
# Run with host networking (container shares host's network stack)
docker run --name dreamroute-host --rm -d --network host ${REPOSITORY}:${TAG}

# Create a custom network
docker network create springboot-network

# Run container in custom network
docker run --name dreamroute-network --rm -d --network springboot-network -p 8080:8080 ${REPOSITORY}:${TAG}

# Connect running container to additional network
docker network connect bridge dreamroute-network

# Inspect network details
docker network inspect springboot-network

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
docker logs -f dreamroute
```

### 🐚 Access the Container Shell

Spawn an interactive shell inside the running container:

```bash
docker exec -ti dreamroute /bin/bash
```

## 📊 Container Management & Monitoring

Advanced container management and monitoring commands:

### 📈 Container Statistics

```bash
# Real-time container statistics
docker stats dreamroute

# One-time stats for all containers
docker stats --no-stream

# Stats with custom format
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
```

### 🔍 Container Inspection

```bash
# Get detailed container information
docker inspect dreamroute

# Get specific information using Go templates
docker inspect dreamroute --format='{{.State.Status}}'
docker inspect dreamroute --format='{{.NetworkSettings.IPAddress}}'
docker inspect dreamroute --format='{{.Config.Image}}'

# Get container processes
docker top dreamroute

# Get container port mappings
docker port dreamroute
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
docker ps --filter "name=dreamroute"
docker ps --filter "status=running"
```

### ⏯️ Container Lifecycle Management

```bash
# Pause/unpause a container
docker pause dreamroute
docker unpause dreamroute

# Restart a container
docker restart dreamroute

# Rename a container
docker rename dreamroute springboot-dreamroute

# Update container resources
docker update --memory="512m" --cpus="1.0" dreamroute
```

### 📁 Container File Operations

```bash
# Copy files from container to host
docker cp dreamroute:/app/app.jar ./app.jar

# Copy files from host to container
docker cp ./config.properties dreamroute:/app/

# Create a new image from container changes
docker commit dreamroute ${REPOSITORY}:modified
```

### 💾 Volume and Data Management

Work with Docker volumes and bind mounts:

```bash
# Create a named volume
docker volume create springboot-data

# Run container with named volume for logs
docker run --name dreamroute-volume --rm -d -p 8080:8080 \
  -v springboot-data:/app/logs ${REPOSITORY}:${TAG}

# Run container with bind mount (mount host directory for configuration)
docker run --name dreamroute-bind --rm -d -p 8080:8080 \
  -v $(pwd)/config:/app/config ${REPOSITORY}:${TAG}

# Run container with read-only volume
docker run --name dreamroute-readonly --rm -d -p 8080:8080 \
  -v $(pwd)/config:/app/config:ro ${REPOSITORY}:${TAG}

# Run container with temporary filesystem (tmpfs)
docker run --name dreamroute-tmpfs --rm -d -p 8080:8080 \
  --tmpfs /tmp ${REPOSITORY}:${TAG}

# List all volumes
docker volume ls

# Inspect volume details
docker volume inspect springboot-data

# Remove unused volumes
docker volume prune

# Remove specific volume
docker volume rm springboot-data
```

## 🗄️ Database Setup with Docker

The DreamRoute application requires a MySQL database. This section shows how to run a MySQL database container with proper initialization and connect your Spring Boot application to it.

### 📋 Database Environment File

Create a database environment file for MySQL initialization:

```bash
cat << EOF > db.env
MYSQL_ROOT_PASSWORD=rootpassword123
MYSQL_DATABASE=dreamroute
MYSQL_USER=dreamroute_user
MYSQL_PASSWORD=dreamroute_pass
EOF
```

### 🚀 Run MySQL Database Container

Run a MySQL container with the environment file:

```bash
# Run MySQL container with environment file
docker run --name dreamroute-mysql --rm -d \
  -p 3306:3306 \
  --env-file db.env \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0
```

```
# Alternative: Run with explicit environment variables
docker run --name dreamroute-mysql --rm -d \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=rootpassword123 \
  -e MYSQL_DATABASE=dreamroute \
  -e MYSQL_USER=dreamroute_user \
  -e MYSQL_PASSWORD=dreamroute_pass \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0
```

Test:

```
sudo apt install mysql-client
mysql --user=dreamroute_user --password=dreamroute_pass dreamroute --host=127.0.0.1
```

### 🔗 Application Environment File

Create an environment file for the Spring Boot application with database credentials:

```bash
cat << EOF > app.env
DB_URL=jdbc:mysql://dreamroute-mysql:3306/dreamroute
DB_USERNAME=dreamroute_user
DB_PASSWORD=dreamroute_pass
SPRING_PROFILES_ACTIVE=production
JAVA_OPTS=-Xmx512m
EOF
```

### 🔄 Run Application with Database Connection

#### Method 1: Using Host Network (simpler for local development)

1. Run MySQL on host network

```bash
docker run --name dreamroute-mysql --rm -d \
  --network host \
  --env-file db.env \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0
```

2. Create an environment file for the Spring Boot application with the localhost database credentials.

```bash
cat << EOF > app-localhost.env
DB_URL=jdbc:mysql://localhost:3306/dreamroute
DB_USERNAME=dreamroute_user
DB_PASSWORD=dreamroute_pass
SPRING_PROFILES_ACTIVE=development
JAVA_OPTS=-Xmx512m
EOF
```

3. Run Spring Boot application

```bash
docker run --name dreamroute-app --rm \
  --network host \
  --env-file app-localhost.env \
  ${REPOSITORY}:${TAG}
```

#### Method 2: Using Docker Network

Create a custom network and run both containers:

1. Create a custom network

```bash
docker network create dreamroute-network
```

2. Run MySQL in the network

```bash
docker run --name dreamroute-mysql --rm -d \
  --network dreamroute-network \
  --env-file db.env \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0
```

3. Wait for MySQL to be ready (check logs)

```bash
docker logs -f dreamroute-mysql
```

4. Run Spring Boot application in the same network

```bash
docker run --name dreamroute-app --rm -d \
  --network dreamroute-network \
  -p 8080:8080 \
  --env-file app.env \
  ${REPOSITORY}:${TAG}
```

### 🔍 Database Management Commands

Useful commands for managing the database container:

```bash
# Check MySQL container logs
docker logs -f dreamroute-mysql

# Access MySQL shell
docker exec -it dreamroute-mysql mysql -u dreamroute_user -p

# Execute SQL commands from host
docker exec -i dreamroute-mysql mysql -u dreamroute_user -p dreamroute < script.sql

# Backup database
docker exec dreamroute-mysql mysqldump -u dreamroute_user -p dreamroute > backup.sql

# Restore database
docker exec -i dreamroute-mysql mysql -u dreamroute_user -p dreamroute < backup.sql

# Check database status
docker exec dreamroute-mysql mysqladmin -u dreamroute_user -p status
```

### 🧪 Test Database Connection

Test the connection between application and database:

```bash
# Check application logs for database connection
docker logs -f dreamroute-app

# Test application endpoints
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/users

# Check database from application container
docker exec -it dreamroute-app /bin/bash
# Inside container: try connecting to database host
```

### 🧹 Database Cleanup

Clean up database resources:

```bash
# Stop containers
docker stop dreamroute-app dreamroute-mysql

# Remove network
docker network rm dreamroute-network

# Remove volume (WARNING: This deletes all data!)
docker volume rm mysql-data

# Remove environment files
rm db.env app.env
```

## ☁️ Push the Container to Docker Hub

### 📤 Push the Image

Push the image to the Docker Hub registry:

```bash
docker push ${REPOSITORY}:${TAG}
```

```
The push refers to repository [docker.io/raelga/springboot]
a1b2c3d4e5f6: Pushed
b2c3d4e5f6a1: Pushed
c3d4e5f6a1b2: Pushed
d4e5f6a1b2c3: Pushed
e5f6a1b2c3d4: Pushed
f6a1b2c3d4e5: Pushed
v1: digest: sha256:abc123def456... size: 2850
```

Check your published image:

```bash
echo https://hub.docker.com/r/${REPOSITORY}
```

## 🧹 Cleanup

### Stop and Remove the Container

If running in background mode:

```bash
docker stop dreamroute
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
   docker ps | grep dreamroute
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
