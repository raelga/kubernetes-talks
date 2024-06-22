# Hello World NGINX


Export some environment variables

```
export REPOSITORY=raelga/hello-world-go
```

## Build the v1 container

Build the container image:

```
docker build -t ${REPOSITORY}:v1 v1
```

## Run the v1 container

Run the container and attach your terminal:

```
docker run --rm -p 9999:9999 ${REPOSITORY}:v1
```

Run the container in the background:

```
docker run --rm -d -p 9999:9999 ${REPOSITORY}:v1
```

## Build the v2 container

Build the container image:

```
docker build -t ${REPOSITORY}:v2 v2
```

## Run the v2 container

Run the container and attach your terminal:

```
docker run --rm -p 8888:9999 ${REPOSITORY}:v2
```

Network namespaces in action.