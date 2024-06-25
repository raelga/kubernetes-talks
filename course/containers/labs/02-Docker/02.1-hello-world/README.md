# Building docker images

## Hello World v1

v1 folder includes a Dockerfile with the following directives:

```
FROM alpine:latest
CMD ["/bin/echo", "Hello World!"]
```

To build an image, you can use the docker cli:

```
docker build v1 -t hello-world:v1
```

```
Sending build context to Docker daemon  3.072kB
Step 1/2 : FROM alpine:latest
latest: Pulling from library/alpine
31e352740f53: Pull complete
Digest: sha256:82d1e9d7ed48a7523bdebc18cf6290bdb97b82302a8a9c27d4fe885949ea94d1
Status: Downloaded newer image for alpine:latest
 ---> c1aabb73d233
Step 2/2 : CMD ["/bin/echo", "Hello World!"]
 ---> Running in 8d679711945a
Removing intermediate container 8d679711945a
 ---> b443150e5d38
Successfully built b443150e5d38
Successfully tagged hello-world:v1
```

The image has been created and now is available:

```
docker inspect hello-world:v1
```

```
[
    {
        "Id": "sha256:b443150e5d383388296e8a0ab54d0fa192ef5d7cf8f3f4c29fb792ecbda826ab",
        "RepoTags": [
            "hello-world:v1"
        ],
        "RepoDigests": [],
        "Parent": "sha256:c1aabb73d2339c5ebaa3681de2e9d9c18d57485045a4e311d9f8004bec208d67",
        "Comment": "",
        "Created": "2023-06-21T12:15:29.646933365Z",
        "Container": "8d679711945abb7f959f97719741da1b046550550a39c973b8766340b3889c54",
        "ContainerConfig": {
            "Hostname": "8d679711945a",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "/bin/sh",
                "-c",
                "#(nop) ",
                "CMD [\"/bin/echo\" \"Hello World!\"]"
            ],
            "Image": "sha256:c1aabb73d2339c5ebaa3681de2e9d9c18d57485045a4e311d9f8004bec208d67",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": {}
        },
        "DockerVersion": "20.10.21",
        "Author": "",
        "Config": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "/bin/echo",
                "Hello World!"
            ],
            "Image": "sha256:c1aabb73d2339c5ebaa3681de2e9d9c18d57485045a4e311d9f8004bec208d67",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": null
        },
        "Architecture": "amd64",
        "Os": "linux",
        "Size": 7331611,
        "VirtualSize": 7331611,
        "GraphDriver": {
            "Data": {
                "MergedDir": "/var/lib/docker/overlay2/df2ab31b066ec107adc202e7abee5b7907a5a1fb926d26bef14fe93e45d82489/merged",
                "UpperDir": "/var/lib/docker/overlay2/df2ab31b066ec107adc202e7abee5b7907a5a1fb926d26bef14fe93e45d82489/diff",
                "WorkDir": "/var/lib/docker/overlay2/df2ab31b066ec107adc202e7abee5b7907a5a1fb926d26bef14fe93e45d82489/work"
            },
            "Name": "overlay2"
        },
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:78a822fe2a2d2c84f3de4a403188c45f623017d6a4521d23047c9fbb0801794c"
            ]
        },
        "Metadata": {
            "LastTagTime": "2023-06-21T12:15:29.660537507Z"
        }
    }
]
```

We can now run the container image:

```
docker run hello-world:v1
```

## Hello world v2 and v3

```
docker build v2 -t hello-world:v2
```

```
Sending build context to Docker daemon  3.072kB
Step 1/3 : FROM alpine:latest
 ---> c1aabb73d233
Step 2/3 : RUN echo "Hello World from a file!" >/hello.txt
 ---> Running in cef17cd5107c
Removing intermediate container cef17cd5107c
 ---> 09bce474ad42
Step 3/3 : CMD ["/bin/cat", "/hello.txt"]
 ---> Running in 08c233ea2e44
Removing intermediate container 08c233ea2e44
 ---> 9a78c01b39bf
Successfully built 9a78c01b39bf
Successfully tagged hello-world:v2
```

```
docker build v3 -t hello-world:v3
```

```
Sending build context to Docker daemon  3.072kB
Step 1/4 : FROM alpine:latest
 ---> c1aabb73d233
Step 2/4 : RUN echo "Hello World from a file!" >/hello.txt
 ---> Using cache                         <=== Cached from previous build
 ---> 09bce474ad42
Step 3/4 : RUN echo "Saving some info for later." >/later.txt
 ---> Running in ff977df4f23c
Removing intermediate container ff977df4f23c
 ---> b81477137d11
Step 4/4 : CMD ["/bin/cat", "/hello.txt"]
 ---> Running in 2c87fb5f92f3
Removing intermediate container 2c87fb5f92f3
 ---> cad59e7b9c75
Successfully built cad59e7b9c75           <=== uuid
Successfully tagged hello-world:v3        <=== tag
```

## Take a look to the docker directory

```
cd /var/lib/docker/
```

```
sudo tree /var/lib/docker/overlay2/
```

```
/var/lib/docker/overlay2/
├── 527bd78f86e50b8cd92a795ca7a76aa70010254d3bb308ffc82183b3d8990181
│   ├── committed
│   ├── diff
│   │   └── later.txt
│   ├── link
│   ├── lower
│   └── work
...
├── cb273e73c998668f7d4c1f6b5a69736616cb635b614e6ba5acecb33623f6ad17
│   ├── committed
│   ├── diff
│   │   └── hello.txt
│   ├── link
│   ├── lower
│   └── work
...
```
