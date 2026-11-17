# Docker Compose Lab: WordPress Multi-Instance Deployment

## Learning Objectives

- Deploy and inspect two isolated WordPress and MariaDB environments with Docker Compose.
- Explore service networking, port mappings, and persistent volumes.
- Manage each project's lifecycle independently.

## Prerequisites

- Docker running and Docker Compose V2 installed (`sudo apt install docker-compose-v2` if needed on a compatible Ubuntu host).
- Terminal access and a basic understanding of containers and web applications.
- Run all commands below from this directory, `03.1-wordpress`.

Docker Compose defines multi-container applications in YAML. See the [Compose documentation](https://docs.docker.com/compose/).

### Security and browser access

The YAML files contain **public, weak, hard-coded database credentials** intended only for this disposable lab. Environment variables can be inspected by users with Docker access. Do not reuse these passwords or commit real credentials; use strong, unique credentials and an appropriate secret manager for real deployments. MariaDB initialization variables only apply to a new database volume: changing the YAML does not change credentials in an existing database.

The published ports bind to the host interfaces, so other machines that can reach them may see the WordPress setup wizard and claim an unconfigured site. Configure the admin accounts promptly, use unique passwords, and restrict access to trusted clients. These examples do not provide HTTPS and are not production deployments.

- **Local Docker host:** browse to `http://localhost` and `http://localhost:81` on that same machine.
- **Remote EC2 host:** `localhost` on your laptop refers to your laptop, not EC2. Use `http://<EC2-public-IP-or-DNS>` and `http://<EC2-public-IP-or-DNS>:81` from your browser. The instance needs a reachable public address, routing, and inbound TCP ports 80 and 81 permitted by its security group and any host/network firewall. Restrict inbound rules to your own public IP rather than opening them to the world, and remove the rules after the lab. If the instance has no public address, use an approved tunnel or other private access method instead. Follow the permissions and cleanup rules of your assigned environment.

## Exercise 1: First WordPress Project

1. Inspect `docker-compose.yaml`: it defines `db` and `wordpress`, with host port 80 and named database and WordPress volumes.

   ```bash
   cat docker-compose.yaml
   docker compose -p wp-first -f docker-compose.yaml up -d
   docker compose -p wp-first -f docker-compose.yaml ps
   ```

2. Open the first URL for your host above, complete the WordPress setup wizard, and create an admin account. Database initialization can take time: `depends_on` starts the database container first but does not wait for it to be ready.

## Exercise 2: Second WordPress Project

1. Inspect `second-wordpress.yaml`: it defines `db2` and `wordpress2`, host port 81, and separate named volumes.

   ```bash
   cat second-wordpress.yaml
   docker compose -p wp-second -f second-wordpress.yaml up -d
   docker compose -p wp-second -f second-wordpress.yaml ps
   ```

2. Open the second URL for your host and complete its separate setup. It has its own database and WordPress files.

The explicit project names `wp-first` and `wp-second` give the two configurations independent Compose networks, containers, and project-scoped volumes. Always use the same `-p` and `-f` pair when managing each project; using only `-f` in the same directory would normally select the same default project name and could treat the other project's services as orphans.

## Exercise 3: Explore and Inspect

```bash
# Logs for each project's actual service names
docker compose -p wp-first -f docker-compose.yaml logs wordpress db
docker compose -p wp-second -f second-wordpress.yaml logs wordpress2 db2

# Project-specific service status and processes
docker compose -p wp-first -f docker-compose.yaml ps
docker compose -p wp-first -f docker-compose.yaml top
docker compose -p wp-second -f second-wordpress.yaml ps
docker compose -p wp-second -f second-wordpress.yaml top

docker network ls
docker volume ls
```

Confirm both sites are accessible on their respective ports. Create a post on the first site, restart only that project's containers, and confirm the post remains:

```bash
docker compose -p wp-first -f docker-compose.yaml restart
```

Named volumes retain data across container restarts and ordinary `down` operations.

## Cleanup

Stop and remove both projects' containers and networks while preserving their data:

```bash
docker compose -p wp-first -f docker-compose.yaml down
docker compose -p wp-second -f second-wordpress.yaml down
```

To also **permanently delete both projects' WordPress files and databases**, use `down -v` for each project instead. This also works after the ordinary `down` commands above:

```bash
docker compose -p wp-first -f docker-compose.yaml down -v
docker compose -p wp-second -f second-wordpress.yaml down -v
```

Remove any temporary EC2 security-group rules you added and clean up the lab host according to your environment's instructions.

## Troubleshooting

- **Port already in use:** identify the conflicting process or container and stop it, or change the host-side port mapping and use the new port in the browser and firewall rules.
- **Cannot reach the site:** check the correct local or EC2 address and port, project status, security-group ingress, routing, and host firewall. Do not use laptop `localhost` for an application running on EC2.
- **Database connection error:** allow time for initialization and inspect the relevant project logs. Existing database volumes retain their original credentials.
- **Containers fail to start:** inspect the appropriate project's logs and available Docker resources.
