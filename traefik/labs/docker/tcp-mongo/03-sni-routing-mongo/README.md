# TCP with SNI Routing in Traefik and Mongo Backends

* (Optional): Re-generate Certificates:

```shell
bash ../root-certs/generate-certificates.sh "mongo1.local,mongo2.local" ./
```

* Start the stack:

```shell
docker-compose up -d
```

* Update your `/etc/hosts`:

```text
...
127.0.0.1   mongo1.local mongo2.local
```

* Connect local `mongo` client to mongo's backend through Traefik:

```shell
# Mongo 1
mongo --host mongo1.local --port 27017 --ssl --sslCAFile=../root-certs/minica.pem --sslPEMKeyFile=./certs/mongo.pem
> show dbs
> use meetup
> db.movie.insert({"name":"Traefik-Awesome"})
> show dbs
> exit
```

```shell
# Mongo2
mongo --host mongo2.local --port 27017 --ssl --sslCAFile=../root-certs/minica.pem --sslPEMKeyFile=./certs/mongo.pem
> show dbs
> exit
```

* Cleanup:

```shell
docker-compose down -v
```
