# Users and PIDs: host vs container

Run one small Go service twice — once directly on the Linux host, once in a container — and compare what it reports about accounts and processes. The same binary returns different answers because of what Docker isolates, and identical answers where Docker isolates nothing.

The lab runs on the course [EC2 instance](../../../terraform/aws-academy-ec2-instance/README.md) (Ubuntu). Run the commands there as the default `ubuntu` user; no Go toolchain is needed on the host.

## 🎯 Learning Objectives

- See a PID namespace shrink hundreds of host processes down to one
- See that `/etc/passwd` inside a container is image content, not host content
- Show that mounting the host's `/etc/passwd` restores the host user list while processes stay isolated
- Map the container's PID 1 to a host PID
- Distinguish process isolation (a namespace) from filesystem content (a file)

## 🔌 The service

| Endpoint | Reads | Response |
| --- | --- | --- |
| `/` | `/etc/passwd`, `/proc`, uid/gid | summary: uid, gid, hostname, user count, PID count |
| `/users` | `/etc/passwd` | one line per account: `uid<TAB>gid<TAB>name` |
| `/pids` | `/proc` | one line per process: `pid<TAB>comm` |

The service listens on `:9999` and has no health endpoint; `/` doubles as a quick check.

## 🛠️ Build the image

```bash
cd 02.3-isolation
docker build -t isolation-demo:v1 .
```

The `Dockerfile` uses a multi-stage build and an Alpine runtime image with a non-root `appuser` (UID 1001).

The Makefile wraps the same commands:

| Target | Effect |
| --- | --- |
| `make build` | build `isolation-demo:v1` |
| `make host` | build, extract the binary to `./app-host`, run it on the host (`:9999`) |
| `make run` | run the container with the host port from `HOST_PORT` (default `8888`) |
| `make stop` | stop containers from this image |
| `make clean` | remove `./app-host` |

## 1️⃣ Run it on the host

The build produces a static binary, so it also runs directly on the host. Copy it out of the image instead of installing Go:

```bash
docker create --name isolation-extract isolation-demo:v1
docker cp isolation-extract:/app/app ./app-host
docker rm isolation-extract
chmod +x app-host
./app-host
```

In a second terminal:

```bash
curl http://localhost:9999/
```

```text
uid=1000 gid=1000 hostname=ip-172-31-12-34
users=40
pids=142

GET /users	accounts from /etc/passwd
GET /pids	processes from /proc
```

You are user `ubuntu` (UID 1000), the account list is the host's `/etc/passwd` and the process list is the host's `/proc`. Cross-check with the host's own tools:

```bash
wc -l < /etc/passwd
ls /proc | grep -cE '^[0-9]+$'
ps -e --no-headers | wc -l
```

The counts match the service output (PIDs come and go between commands, so small differences are expected).

Leave the host service running for the comparisons below.

## 2️⃣ Run it in a container

```bash
docker run -d --rm --name isolation-lab -p 8888:9999 isolation-demo:v1
curl http://localhost:8888/
```

```text
uid=1001 gid=1001 hostname=9d3a3c7b2f10
users=28
pids=1

GET /users	accounts from /etc/passwd
GET /pids	processes from /proc
```

Three things changed:

| Field | On the host | In the container | Why |
| --- | --- | --- | --- |
| `uid`/`gid` | 1000 | 1001 | `USER appuser` in the image |
| `users` | host accounts | 28 accounts | `/etc/passwd` comes from the image |
| `pids` | host processes | 1 | Docker created a PID namespace |

```bash
curl http://localhost:8888/pids
```

```text
1	app
```

The process is PID 1 inside the container, and every other host process is invisible. Same binary, same machine, different namespace.

Look at the accounts:

```bash
curl http://localhost:8888/users
```

```text
0	0	root
1	1	bin
2	2	daemon
3	4	adm
...
1001	1001	appuser
```

Those are Alpine's busybox accounts plus `appuser`, not your instance's accounts. `/etc/passwd` is just a file in the image; nothing namespaced it.

### Map PID 1 to a host PID

```bash
docker inspect isolation-lab --format '{{.State.Pid}}'
```

That is the host PID of the container's PID 1 (`app`). Compare:

```bash
sudo ps -p $(docker inspect isolation-lab --format '{{.State.Pid}}') -o pid,user,comm
```

On the host the process is owned by UID 1001 — the container's `appuser` — so it appears as `1001` unless your instance has a name for that UID. It is not root.

## 3️⃣ Keep the host PID namespace

```bash
docker run -d --rm --name isolation-hostpid --pid=host -p 8889:9999 isolation-demo:v1
curl http://localhost:8889/
```

```text
uid=1001 gid=1001 hostname=9d3a3c7b2f10
users=28
pids=142
```

`--pid=host` removes the PID namespace: the host processes are back, while the accounts stay at 28 and the uid stays 1001. So the process isolation came from the PID namespace, not from the container itself.

`docker inspect` now reports the container's own PID, because PID 1 **is** a host process:

```bash
docker inspect isolation-hostpid --format '{{.State.Pid}}'
```

## 4️⃣ Mount the host's account file

Replace the image's `/etc/passwd` with the host's:

```bash
docker run -d --rm --name isolation-users --user 1001 -p 8890:9999 \
  -v /etc/passwd:/etc/passwd:ro isolation-demo:v1
curl http://localhost:8890/
```

```text
uid=1001 gid=0 hostname=9d3a3c7b2f10
users=40
pids=1
```

The host accounts are visible, but processes are still isolated. Users are not a namespace in this setup: the container simply reads whatever `/etc/passwd` you give it. `:ro` mounts it read-only, so the container cannot rename accounts on the host.

`--user 1001` is required here. The image says `USER appuser`, and Docker resolves that name against `/etc/passwd` while creating the container — replace the file and the name no longer exists, so creation fails with `unable to find user appuser: no matching entries in passwd file`. The numeric UID always resolves. `gid` becomes 0 for the same reason: without a name, Docker uses the image's default group unless you also pass `--user 1001:1001`.

On Ubuntu, `/etc/passwd` is world-readable (`-rw-r--r--`), so UID 1001 can read it. If your host restricts it, `/users` returns `permission denied` and the mode is the reason, not Docker.

## 📊 Summary

| Run | uid | users | pids |
| --- | --- | --- | --- |
| `./app-host` on the host | 1000 | host accounts | host processes |
| `docker run` | 1001 | image accounts | 1 |
| `docker run --pid=host` | 1001 | image accounts | host processes |
| `docker run --user 1001 -v /etc/passwd:...` | 1001 | host accounts | 1 |

Isolation comes from kernel namespaces (PID, mount, network…) and from the image filesystem. A file that happens to be at the host path can be replaced by a mount; a namespace cannot be removed by a container flag on the app, only by asking the runtime for the host namespace.

## 🧹 Clean up

```bash
docker rm -f isolation-lab isolation-hostpid isolation-users
# stop the host service with Ctrl+C in its terminal
rm -f app-host
docker rmi isolation-demo:v1
```

## 🐛 Troubleshooting

### Port already in use

```bash
sudo ss -ltnp | grep -E ':(9999|8888|8889|8890)'
```

Stop whatever holds the port, or change the host side of `-p`.

### `permission denied` running `app-host`

You copied the binary from the builder stage before `chmod +x`, or the copy was made without the file mode:

```bash
chmod +x app-host
```

### `users=error` or `pids=error`

The service could not read `/etc/passwd` or `/proc`. A `scratch`-based image would have no `/etc/passwd`; this lab's Alpine image does. If you mounted a host file, check its permissions — the service runs as UID 1001.

### `unable to find user appuser: no matching entries in passwd file`

You replaced `/etc/passwd` without passing `--user`. Docker resolves the image's `USER appuser` against the file being mounted. Add `--user 1001` (or `--user 1001:1001`).

### Counts do not match `ps`

`/proc` reflects the exact instant of the request. Processes start and exit continuously on the host, so a few units of difference between `curl` and `ps` are normal. Inside the container the count should be exactly `1`.
