# Docker Compose Lab: WordPress Multi-Instance Deployment

## Learning Objectives

By the end of this lab, you will be able to:
- Understand Docker Compose fundamentals and multi-container orchestration
- Deploy WordPress applications with separate databases using Docker Compose
- Run multiple isolated WordPress instances on different ports
- Manage container lifecycles and inspect running services
- Understand volume persistence and container networking

## Prerequisites

- Docker installed and running
- Docker Compose V2 installed
- Basic understanding of containers and web applications
- Terminal/command line access

## Overview

Docker Compose is a tool for defining and running multi-container applications. It uses YAML files to configure application services, making it easy to deploy complex applications with multiple interconnected containers.

**Documentation:** https://docs.docker.com/compose/

### Installation (if needed)

```bash
sudo apt install docker-compose-v2
```

## Lab Exercises

### Exercise 1: Deploy First WordPress Instance

1. **Examine the Docker Compose configuration:**
   ```bash
   cat docker-compose.yaml
   ```
   
   Notice the two services defined:
   - `db`: MariaDB database container
   - `wordpress`: WordPress application container

2. **Start the WordPress environment:**
   ```bash
   docker compose up -d
   ```
   
   The `-d` flag runs containers in detached mode (background).

3. **Verify the deployment:**
   ```bash
   docker ps
   ```
   
   Expected output:
   ```
   CONTAINER ID   IMAGE                  COMMAND                  CREATED         STATUS         PORTS                               NAMES
   bd1090b9d8dc   wordpress:latest       "docker-entrypoint.s…"   6 minutes ago   Up 5 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   wordpress-wordpress-1
   c06947ad222e   mariadb:10.6.4-focal   "docker-entrypoint.s…"   6 minutes ago   Up 5 minutes   3306/tcp, 33060/tcp                 wordpress-db-1
   ```

4. **Access WordPress:**
   - Open your browser and navigate to `http://localhost`
   - Complete the WordPress setup wizard
   - Create an admin account and log in

### Exercise 2: Deploy Second WordPress Instance

1. **Examine the second configuration:**
   ```bash
   cat second-wordpress.yaml
   ```
   
   Notice the differences:
   - Different service names (`db2`, `wordpress2`)
   - Different port mapping (81:80)
   - Separate volumes to avoid conflicts

2. **Deploy the second instance:**
   ```bash
   docker compose -f second-wordpress.yaml up -d
   ```

3. **Verify both instances are running:**
   ```bash
   docker ps
   ```
   
   Expected output:
   ```
   CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                               NAMES
   7fa15fede63a   wordpress:latest       "docker-entrypoint.s…"   5 minutes ago    Up 5 minutes    0.0.0.0:81->80/tcp, :::81->80/tcp   wordpress-wordpress2-1
   f7637486e1c0   mariadb:10.6.4-focal   "docker-entrypoint.s…"   5 minutes ago    Up 5 minutes    3306/tcp, 33060/tcp                 wordpress-db2-1
   bd1090b9d8dc   wordpress:latest       "docker-entrypoint.s…"   20 minutes ago   Up 12 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   wordpress-wordpress-1
   c06947ad222e   mariadb:10.6.4-focal   "docker-entrypoint.s…"   20 minutes ago   Up 12 minutes   3306/tcp, 33060/tcp                 wordpress-db-1
   ```

4. **Access the second WordPress instance:**
   - Open your browser and navigate to `http://localhost:81`
   - Notice this is a completely separate WordPress installation

### Exercise 3: Explore and Inspect

1. **View container logs:**
   ```bash
   docker compose logs wordpress
   docker compose logs db
   ```

2. **Check Docker networks:**
   ```bash
   docker network ls
   ```

3. **Inspect volumes:**
   ```bash
   docker volume ls
   ```

4. **View detailed service information:**
   ```bash
   docker compose ps
   docker compose top
   ```

## Verification Steps

✅ **Check that both WordPress sites are accessible:**
- Site 1: `http://localhost` (should show WordPress)
- Site 2: `http://localhost:81` (should show WordPress)

✅ **Verify container status:**
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

✅ **Confirm data persistence:**
- Create a post in the first WordPress site
- Restart the containers: `docker compose restart`
- Verify the post is still there

## Cleanup

When you're finished with the lab:

```bash
# Stop and remove first WordPress instance
docker compose down

# Stop and remove second WordPress instance  
docker compose -f second-wordpress.yaml down

# Optional: Remove volumes (this will delete all WordPress data)
docker compose down -v
docker compose -f second-wordpress.yaml down -v
```

## Troubleshooting

**Issue: Port already in use**
```
Error: bind: address already in use
```
**Solution:** Check what's using the port and stop it, or modify the port mapping in the compose file.

**Issue: Cannot connect to database**
```
Error establishing a database connection
```
**Solution:** Wait a few more seconds for the database to fully initialize, or check container logs for database errors.

**Issue: Containers not starting**
**Solution:** Check logs with `docker compose logs` and ensure Docker has enough resources allocated.

## Key Concepts Learned

- **Multi-container orchestration:** Using Docker Compose to manage related services
- **Service isolation:** Running multiple instances without conflicts
- **Volume persistence:** Data survives container restarts
- **Container networking:** Services can communicate using service names
- **Port mapping:** Exposing services on different host ports