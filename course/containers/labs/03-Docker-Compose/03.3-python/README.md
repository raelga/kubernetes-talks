# 03.3 · Two-service Python application with Compose

In this guided exercise you will start two Python services, check their communication and persistence, and diagnose a prepared failure. Spend approximately one hour on Python validation and AI-assisted code review, integrated into the Containers II session.

## Prerequisites

- Docker running and Docker Compose V2 (`docker compose`).
- Python 3 on the machine accessing the published port; no external packages are needed.
- Port 8080 available. Run the commands from this directory. If you are working on a remote machine, run `validar.py` there too: the port is published only on its localhost interface.

## 1. Understand and start the services

Examine `compose.yaml`, `Dockerfile`, `frontend.py`, and `backend.py`. Both services are built from the same image, but run different programs:

- `frontend` publishes port 8080 on localhost and forwards requests to `http://backend:8000`.
- `backend` listens on port 8000 on the Compose network, without publishing it on the host. It stores notes in SQLite at `/data/notas.db`, inside the named volume `datos`.

The name `backend` is a service name resolvable on the Compose network, not `localhost`: inside the frontend, `localhost` refers to the frontend container itself. `depends_on` establishes startup order, but does not guarantee that the backend is ready to receive requests.

```bash
docker compose up -d --build
docker compose ps
docker compose logs backend frontend
```

Wait a few seconds if the backend is still starting. Check communication end to end: the health response comes from the backend through the frontend.

```bash
curl -i http://localhost:8080/health
```

It should return HTTP 200 and `{"servicio": "backend", "estado": "ok"}`. Inspect the port mapping, the `BACKEND_URL` variable, and the `/data` mount using `docker compose ps` and `docker inspect` on the containers (`docker compose ps -q frontend` and `docker compose ps -q backend`). Also find the networks and volumes with `docker network ls` and `docker volume ls`.

## 2. Validate with Python and check persistence

Use a unique text value, different from previous notes, so the check cannot produce a false positive from old data. The script checks health, creates the note, and reads it through both services; if anything fails it exits with a nonzero code.

```bash
NOTA="prueba-$(date +%s)"
python3 validar.py crear "$NOTA"
```

Recreate the containers **without deleting the volume** and check the same text without creating it again:

```bash
docker compose down
docker compose up -d
python3 validar.py comprobar "$NOTA"
```

If the services are still starting, wait and repeat the check. Success demonstrates that the note survived container removal and recreation, not just a process restart. Explain what would happen if `/data` were not mounted on a volume. You can also view the notes directly using `curl http://localhost:8080/notas`.

## 3. Diagnose the prepared failure

This override file changes the backend name to a nonexistent one; it does not modify the data. Apply it and observe the failure:

```bash
docker compose -f compose.yaml -f compose.fallo.yaml up -d frontend
curl -i http://localhost:8080/health
docker compose -f compose.yaml -f compose.fallo.yaml logs frontend
```

The request should return HTTP 502; the logs indicate the destination that could not be resolved or reached. Compare `BACKEND_URL` in the two files and explain why the service name matters. Check the status and effective configuration if needed:

```bash
docker compose -f compose.yaml -f compose.fallo.yaml ps
docker compose -f compose.yaml -f compose.fallo.yaml config
```

Restore the original configuration, recreate the frontend, and validate the existing note:

```bash
docker compose -f compose.yaml up -d frontend
python3 validar.py comprobar "$NOTA"
```

## 4. AI-assisted review and evidence

First read `validar.py` and the two services. Ask an AI tool to explain the path of `/health` and `/notas`, review how responses are checked, and identify a possible configuration failure or an additional test. Share only this exercise's code and synthetic data; do not send credentials, private configuration, or real information. If you do not have an AI tool, perform the same review manually and note this limitation.

Do not accept the answer without checking it: identify the line of code supporting each claim and run the proposed check when it is safe. Record the prompt, a summary of the answer, the claim you verified, and its result; distinguish an unexecuted suggestion from a passing test. Also submit the output of `docker compose ps`, validation before and after recreating the containers, the HTTP 502, and validation after restoring the service as evidence.

## Cleanup

```bash
docker compose down
```

This preserves the volume and notes. Only if you want to delete **all data for this Compose project**, run `docker compose down -v`; do not use this option if you need to keep the data. Image building and publishing are covered separately in [ECR](../../02-Docker/02.6-ECR/README.md).
