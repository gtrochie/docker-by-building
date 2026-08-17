# Docker Cheat Sheet

One-page reference. Full explanations are in the module READMEs.

## Mental model (Module 00)
```
image  = read-only layered template (a class)     container = running instance (an object)
registry = stores images                          daemon(dockerd) = engine; docker CLI = client
containers are EPHEMERAL -> keep data in volumes  |  container's main process exits -> container stops
```

## Images (Module 01)
```
docker pull nginx:alpine            docker images              docker history <img>
docker tag src newname:tag          docker inspect <img>       docker rmi <img>
docker image prune [-a]             docker system df
# pin real tags or digests; 'latest' is just a tag, not "newest"
```

## Containers (Module 02)
```
docker run [opts] IMAGE [cmd]       # create + start
  -d detached  -it shell  --rm auto-remove  --name N  -p H:C  -e K=V  --restart unless-stopped
docker ps [-a]                      docker logs [-f] <c>       docker exec -it <c> sh
docker stop|start|restart <c>       docker rm [-f] <c>         docker inspect <c>
docker stats                        docker top <c>
# exit codes: 0 clean · 1 app error · 137 SIGKILL/OOM · 143 SIGTERM
```

## Dockerfile (Module 03)
```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim            # pinned base, not 'latest'
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY app/requirements.txt .      # deps BEFORE code (cache!)
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ .
EXPOSE 8000
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]   # exec form (JSON)
```
`RUN` = build time · `CMD`/`ENTRYPOINT` = run time · use `COPY` not `ADD` ·
add a `.dockerignore` · lint with `hadolint Dockerfile`.
```
docker build -t name:tag .          docker build --no-cache -t name:tag .
```

## Build cache (Module 04)
```
Order matters: an instruction's cache busts -> everything BELOW rebuilds.
Copy rarely-changing deps first, source last.
Combine apt update+install in ONE RUN; clean up in the SAME layer.
Deleting files in a later layer does NOT shrink the image (size is cumulative).
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
```

## Volumes / data (Module 05)
```
docker volume create NAME           docker volume ls|inspect|rm|prune
-v NAME:/path            named volume (persist DB data — survives rm)
-v "$(pwd)/app:/app"     bind mount (live host code in dev)
--tmpfs /path            in-memory only (secrets/scratch)
# 'docker compose down -v' DELETES named volumes (your data). Handle with care.
```

## Networking (Module 06)
```
docker network create NET           docker network ls|inspect|rm
docker run --network NET ...         # containers reach each other by NAME (DNS)
-p H:C publishes to host; internal services need no -p
# inside a container, 'localhost' = that container, NOT the host/another container
# host services from a container: host.docker.internal (Docker Desktop)
```

## Config & secrets (Module 07)
```
ENV K=V (Dockerfile default)   -e K=V / --env-file f (run-time override)
ARG (build-time only, --build-arg)  != ENV (run-time)
NEVER bake secrets into images (visible in history/layers). Inject at run time.
Build secrets: RUN --mount=type=secret,id=x ...  +  docker build --secret id=x,src=./f
```

## Compose (Module 08)
```
docker compose config [--services]  # validate/normalize (no daemon needed)
docker compose up [-d] [--build]     docker compose down [-v]
docker compose ps                    docker compose logs -f [svc]
docker compose exec svc sh           docker compose up -d --scale api=3
# services reach each other by service name; one shared network is auto-created
# wait for readiness:  depends_on: { db: { condition: service_healthy } } + healthcheck
```

## Multi-stage & small images (Module 09)
```dockerfile
FROM python:3.12-slim AS builder
... build into /opt/venv ...
FROM python:3.12-slim AS runtime
COPY --from=builder /opt/venv /opt/venv     # copy ONLY artifacts, not the whole stage
RUN useradd -u 10001 appuser
USER appuser                                 # run non-root
```
Slim/distroless base · no build tools in final image · non-root user.

## Health & debugging (Module 10)
```
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD <probe>
docker inspect --format '{{.State.Health.Status}}' <c>
docker run --memory 256m --cpus 0.5 ...     docker inspect --format '{{.State.OOMKilled}}' <c>
Debug order: logs -> ps -a (exit code) -> inspect -> exec -> events/stats
```

## Registries (Module 11)
```
docker build -t name:1.0 .          docker tag name:1.0 user/repo:1.0
docker login                        docker push user/repo:1.0
docker pull user/repo:1.0           docker run --rm user/repo:1.0
# deploy a real version tag, never :latest
```

## Cleanup
```
docker container prune   docker image prune [-a]   docker volume prune
docker builder prune     docker system prune [-a] [--volumes]   docker system df
```

## The one-liners you'll use daily
```
docker compose up -d --build         # start the stack
docker compose logs -f api           # tail a service
docker exec -it <c> sh               # get inside
docker ps -a                         # what's running / why did it die
docker system df                     # where did my disk go
```
