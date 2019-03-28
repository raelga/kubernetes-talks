# Simple TCP and Mongo Backend

* Start the stack:

```shell
docker-compose up -d
```

* Update your `/etc/hosts`:

```text
...
127.0.0.1   mongo1.local
```

* Connect local `mongo` client to mongo's backend through Traefik:

```shell
mongo --host mongo1.local --port 27017
> show dbs
> exit
```

* Cleanup:

```shell
docker-compose down -v
```
