# Docker Compose Example

Docker Compose is a tool for defining and running multi-container applications. It is the key to unlocking a streamlined and efficient development and deployment experience.

https://docs.docker.com/compose/

```
sudo apt install docker-compose-v2
```

## Wordpress

Review the `docker-compose.yaml` file.

Run the environment in the background:

```
docker compose up -d
```

```
docker ps
````

```
CONTAINER ID   IMAGE                  COMMAND                  CREATED         STATUS         PORTS                               NAMES
bd1090b9d8dc   wordpress:latest       "docker-entrypoint.s…"   6 minutes ago   Up 5 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   wordpress-wordpress-1
c06947ad222e   mariadb:10.6.4-focal   "docker-entrypoint.s…"   6 minutes ago   Up 5 minutes   3306/tcp, 33060/tcp                 wordpress-db-1
```

## Second wordpress

```
docker compose -f second-wordpress.yaml up -d
```

```
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                               NAMES
7fa15fede63a   wordpress:latest       "docker-entrypoint.s…"   5 minutes ago    Up 5 minutes    0.0.0.0:81->80/tcp, :::81->80/tcp   wordpress-wordpress2-1
f7637486e1c0   mariadb:10.6.4-focal   "docker-entrypoint.s…"   5 minutes ago    Up 5 minutes    3306/tcp, 33060/tcp                 wordpress-db2-1
bd1090b9d8dc   wordpress:latest       "docker-entrypoint.s…"   20 minutes ago   Up 12 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   wordpress-wordpress-1
c06947ad222e   mariadb:10.6.4-focal   "docker-entrypoint.s…"   20 minutes ago   Up 12 minutes   3306/tcp, 33060/tcp                 wordpress-db-1
```