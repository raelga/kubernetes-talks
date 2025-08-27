# Docker Compose SpringBoot Lab - DreamRoute Application

This lab demonstrates containerizing a SpringBoot application with MySQL database using Docker Compose. The DreamRoute application is a travel management system with JWT authentication, built with Spring Boot 3.5.3 and Java 21.

## 🎯 Learning Objectives

- Understand multi-container application orchestration with Docker Compose
- Learn service dependencies and health checks
- Practice volume management for data persistence
- Implement container networking and environment configuration
- Experience real-world microservices deployment patterns

## 📋 Prerequisites

Before starting this lab, ensure you have:

- **Docker** (version 20.10 or higher)
- **Docker Compose** (version 2.0 or higher)
- **Git** (for cloning the repository)
- **curl** (for testing endpoints)
- Basic understanding of SpringBoot and MySQL

### Verify Prerequisites

```bash
# Check Docker installation
docker --version
docker-compose --version

# Check Git installation
git --version

# Check curl installation
curl --version
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
# Clone the DreamRoute repository into the src directory
git clone https://github.com/Femcoders-Travellers/DreamRoute.git src
```

### 2. Start the Application Stack

```bash
# Start all services (SpringBoot app + MySQL database)
docker-compose up --build
```

### 3. Verify the Application

```bash
# Wait for services to be healthy (about 1-2 minutes)
# Check application health
curl http://localhost:8080/actuator/health

# Expected response:
# {"status":"UP"}
```

### 4. Access the Application

- **Application URL**: http://localhost:8080
- **Database**: localhost:3306 (accessible externally)

## 📁 Project Structure

```
03.2-SpringBoot/
├── docker-compose.yml          # Multi-container orchestration
├── Dockerfile                  # SpringBoot app container definition
├── README.md                   # This documentation
└── src/                        # DreamRoute SpringBoot application
    ├── pom.xml                 # Maven dependencies (Java 21, Spring Boot 3.5.3)
    ├── mvnw                    # Maven wrapper
    └── src/
        ├── main/
        │   ├── java/com/Travellers/DreamRoute/
        │   │   ├── DreamRouteApplication.java
        │   │   ├── controllers/    # REST API endpoints
        │   │   ├── models/         # JPA entities (User, Role, Destination)
        │   │   ├── repositories/   # Data access layer
        │   │   ├── services/       # Business logic
        │   │   └── security/       # JWT authentication & authorization
        │   └── resources/
        │       ├── application.properties  # App configuration
        │       └── data.sql               # Initial database data
        └── test/                   # Unit and integration tests
```

## 🐳 Docker Compose Architecture

The `docker-compose.yml` defines a two-service architecture:

### Services Overview

| Service | Image | Purpose | Ports | Dependencies |
|---------|-------|---------|-------|--------------|
| `dreamroute-app` | Built from local Dockerfile | SpringBoot application | 8080:8080 | dreamroute-db (healthy) |
| `dreamroute-db` | mysql:8.0 | MySQL database | 3306:3306 | None |

### Key Features

- **Health Checks**: Both services include comprehensive health monitoring
- **Service Dependencies**: App waits for database to be healthy before starting
- **Data Persistence**: MySQL data persists across container restups using volumes
- **Custom Network**: Services communicate through isolated bridge network
- **Environment Configuration**: Database credentials and connection strings via environment variables

## 🔧 Configuration Details

### Application Configuration

The SpringBoot application uses these key configurations:

```properties
# Database Connection (from environment variables)
spring.datasource.url=${DB_URL:jdbc:mysql://localhost:3306/dreamroute}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}

# JPA/Hibernate Settings
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.show-sql=true
spring.sql.init.mode=always
```

### Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `SPRING_PROFILES_ACTIVE` | docker | Activates Docker-specific configuration |
| `SERVER_PORT` | 8080 | SpringBoot server port |
| `DB_URL` | jdbc:mysql://dreamroute-db:3306/dreamroute | Database connection URL |
| `DB_USERNAME` | dreamroute | Database username |
| `DB_PASSWORD` | dreamroute123 | Database password |

### Database Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| `MYSQL_DATABASE` | dreamroute | Initial database name |
| `MYSQL_USER` | dreamroute | Application database user |
| `MYSQL_PASSWORD` | dreamroute123 | Application user password |
| `MYSQL_ROOT_PASSWORD` | root123 | MySQL root password |

## 🛠️ Development Commands

### Docker Compose Operations

```bash
# Start services in background
docker-compose up -d

# Build and start services (force rebuild)
docker-compose up --build

# Start only specific service
docker-compose up dreamroute-db

# Stop all services
docker-compose down

# Stop and remove volumes (⚠️ deletes database data)
docker-compose down -v

# View service status
docker-compose ps

# Follow application logs
docker-compose logs -f dreamroute-app

# Follow database logs
docker-compose logs -f dreamroute-db

# Restart specific service
docker-compose restart dreamroute-app

# Execute commands in running containers
docker-compose exec dreamroute-app bash
docker-compose exec dreamroute-db mysql -u dreamroute -p dreamroute
```

### Manual Docker Commands

```bash
# Build application image manually
docker build -t dreamroute-app .

# Run application container manually (requires external MySQL)
docker run -p 8080:8080 \
  -e DB_URL=jdbc:mysql://host.docker.internal:3306/dreamroute \
  -e DB_USERNAME=dreamroute \
  -e DB_PASSWORD=dreamroute123 \
  dreamroute-app

# Run MySQL container manually
docker run -d \
  --name dreamroute-mysql \
  -p 3306:3306 \
  -e MYSQL_DATABASE=dreamroute \
  -e MYSQL_USER=dreamroute \
  -e MYSQL_PASSWORD=dreamroute123 \
  -e MYSQL_ROOT_PASSWORD=root123 \
  mysql:8.0
```

## 🧪 Testing the Application

### Health Checks

```bash
# Application health endpoint
curl http://localhost:8080/actuator/health

# Database connectivity test
docker-compose exec dreamroute-db mysqladmin ping -h localhost -u dreamroute -p
```

### API Endpoints

The DreamRoute application provides these main endpoints:

```bash
# User Authentication
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'

curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'

# Destinations (requires authentication)
curl http://localhost:8080/api/destinations \
  -H "Authorization: Bearer <your-jwt-token>"

# User management (requires authentication)
curl http://localhost:8080/api/users \
  -H "Authorization: Bearer <your-jwt-token>"
```

### Database Access

```bash
# Connect via Docker Compose
docker-compose exec dreamroute-db mysql -u dreamroute -p dreamroute

# Connect via external MySQL client
mysql -h localhost -P 3306 -u dreamroute -p dreamroute

# Connect as root user
docker-compose exec dreamroute-db mysql -u root -p
```

### Useful SQL Queries

```sql
-- Show all tables
SHOW TABLES;

-- Check users table
SELECT * FROM users;

-- Check destinations table
SELECT * FROM destinations;

-- Check roles table
SELECT * FROM roles;

-- Show database size
SELECT
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'dreamroute';
```

## 🔍 Monitoring and Debugging

### Log Analysis

```bash
# All services logs
docker-compose logs

# Application logs only
docker-compose logs dreamroute-app

# Database logs only
docker-compose logs dreamroute-db

# Real-time log following
docker-compose logs -f

# Logs with timestamps
docker-compose logs -t

# Last 50 lines of logs
docker-compose logs --tail 50
```

### Container Inspection

```bash
# Check container details
docker-compose ps
docker inspect dreamroute-springboot
docker inspect dreamroute-db

# Check resource usage
docker stats dreamroute-springboot dreamroute-db

# Check network configuration
docker network ls
docker network inspect 032-springboot_dreamroute-network

# Check volumes
docker volume ls
docker volume inspect 032-springboot_mysql_data
```

### Performance Monitoring

```bash
# Application metrics (if actuator enabled)
curl http://localhost:8080/actuator/metrics

# Database performance
docker-compose exec dreamroute-db mysql -u root -p -e "SHOW PROCESSLIST;"
docker-compose exec dreamroute-db mysql -u root -p -e "SHOW ENGINE INNODB STATUS\G"
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Issue: Port Already in Use

```bash
# Check what's using port 8080
lsof -i :8080
netstat -tulpn | grep 8080

# Solution 1: Stop conflicting service
sudo kill -9 <PID>

# Solution 2: Use different port
# Edit docker-compose.yml ports section:
# ports:
#   - "8081:8080"
```

#### Issue: Database Connection Failed

```bash
# Check if database container is running
docker-compose ps

# Check database logs
docker-compose logs dreamroute-db

# Verify database is accepting connections
docker-compose exec dreamroute-db mysqladmin ping -u dreamroute -p

# Check environment variables
docker-compose exec dreamroute-app env | grep DB_
```

#### Issue: Application Won't Start

```bash
# Check application logs
docker-compose logs dreamroute-app

# Check if database is healthy
docker-compose ps

# Restart with rebuild
docker-compose down
docker-compose up --build

# Check Java version compatibility
docker-compose exec dreamroute-app java -version
```

#### Issue: Data Not Persisting

```bash
# Check volume exists
docker volume ls | grep mysql_data

# Inspect volume
docker volume inspect 032-springboot_mysql_data

# Check volume mount in container
docker-compose exec dreamroute-db df -h /var/lib/mysql
```

#### Issue: Build Failures

```bash
# Clear Docker cache and rebuild
docker system prune -f
docker-compose build --no-cache dreamroute-app

# Check Dockerfile syntax
docker build -t test .

# Verify source code exists
ls -la src/
```

#### Issue: Network Connectivity

```bash
# Check custom network
docker network ls
docker network inspect 032-springboot_dreamroute-network

# Test inter-container connectivity
docker-compose exec dreamroute-app ping dreamroute-db
docker-compose exec dreamroute-app nslookup dreamroute-db
```

### Debug Mode

For detailed debugging, create a `docker-compose.debug.yml`:

```yaml
version: '3.8'
services:
  dreamroute-app:
    environment:
      - SPRING_PROFILES_ACTIVE=docker,debug
      - LOGGING_LEVEL_ROOT=DEBUG
      - SPRING_JPA_SHOW_SQL=true
    ports:
      - "5005:5005"  # Java debug port
    command: >
      java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
      -jar app.jar

  dreamroute-db:
    environment:
      - MYSQL_GENERAL_LOG=1
      - MYSQL_GENERAL_LOG_FILE=/var/lib/mysql/general.log
```

Run with debug configuration:
```bash
docker-compose -f docker-compose.yml -f docker-compose.debug.yml up
```

## 🧹 Cleanup

### Remove Lab Resources

```bash
# Stop and remove containers
docker-compose down

# Remove containers and volumes (⚠️ deletes all data)
docker-compose down -v

# Remove application image
docker rmi 032-springboot_dreamroute-app

# Remove unused Docker resources
docker system prune -f

# Remove all Docker volumes (⚠️ affects other projects)
docker volume prune -f
```

### Reset to Clean State

```bash
# Complete cleanup for fresh start
docker-compose down -v
docker system prune -f
docker volume prune -f
docker-compose up --build
```

## 📚 Additional Learning Resources

### Docker & Docker Compose
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Multi-stage Builds](https://docs.docker.com/develop/dev-best-practices/)
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)

### Spring Boot
- [Spring Boot Docker Guide](https://spring.io/guides/topicals/spring-boot-docker/)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Spring Boot Configuration Properties](https://docs.spring.io/spring-boot/docs/current/reference/html/application-properties.html)

### MySQL
- [MySQL Docker Hub](https://hub.docker.com/_/mysql)
- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/en/)

## 🎓 Lab Extensions

Try these additional challenges:

1. **Add Redis Cache**: Extend docker-compose.yml with Redis for caching
2. **Environment Profiles**: Create separate compose files for dev/staging/prod
3. **Monitoring Stack**: Add Prometheus and Grafana for metrics
4. **Load Balancing**: Add nginx as reverse proxy with multiple app instances
5. **Backup Strategy**: Implement automated MySQL backups
6. **Security Hardening**: Add secrets management and non-root containers

---

**🎉 Congratulations!** You've successfully deployed a multi-container SpringBoot application using Docker Compose. This foundation prepares you for more advanced containerization patterns and Kubernetes deployments.