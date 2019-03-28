# TCP with TLS termination in Traefik and Mongo Backend

* (Optional): Re-generate Certificates:

```shell
bash ../root-certs/generate-certificates.sh mongo.local ./
```

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
# Should Error because no TLS
mongo --host mongo1.local --port 27017
# Should work
mongo --host mongo1.local --port 27017 --ssl --sslCAFile=../root-certs/minica.pem --sslPEMKeyFile=./certs/mongo.pem
> show dbs
> exit
```

* Cleanup:

```shell
docker-compose down -v
```
