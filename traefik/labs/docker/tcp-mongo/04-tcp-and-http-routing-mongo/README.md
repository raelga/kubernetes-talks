# TCP with SNI Routing in Traefik and Mongo Backends

* (Optional): Re-generate Certificates:

```shell
bash ../root-certs/generate-certificates.sh "mongo1.local,mongo2.local,dashboard-mongo1.local" ./
```

* Start the stack:

```shell
docker-compose up -d
```

* Update your `/etc/hosts`:

```text
...
127.0.0.1   mongo1.local mongo2.local dashboard-mongo1.local
```

* Connect local `mongo` client to mongo's backend through Traefik:

```shell
# Mongo 1
mongo --host mongo1.local --port 27017 --ssl --sslCAFile=../root-certs/minica.pem --sslPEMKeyFile=./certs/mongo.pem
> show dbs
> use another-db-in-the-wall
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

* Open the Mongo Client WebUI at the URL https://dashboard-mongo1.local:27017/ (requires insecure OR adding the minica.pem CA root in your webbrowser): <https://dashboard-mongo1.local:27017/>
  * Check the db "another-db-in-the-wall" exists.

* Cleanup:

```shell
docker-compose down -v
```
