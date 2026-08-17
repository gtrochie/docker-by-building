# Module 10 — Healthchecks & Debugging

Containers fail in production. This module is the toolkit for knowing *when* (health
checks) and *why* (debugging), plus the resource limits that keep one container
from taking down the host.

## Healthchecks — "running" vs "actually working"

A container can be `Up` while the app inside is wedged. A **healthcheck** is a
command Docker runs periodically; its exit code (0 = healthy, non-zero = unhealthy)
drives the container's health status — which Compose and orchestrators use to gate
traffic and trigger restarts.

In a Dockerfile:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; \
    sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"
```

Watch it take effect:

```bash
docker run -d --name api -p 8000:8000 freelanceforge:prod
docker ps
```
```
CONTAINER ID   IMAGE                 STATUS                            PORTS
1a2b3c4d5e6f   freelanceforge:prod   Up 20 seconds (healthy)           0.0.0.0:8000->8000/tcp
```

`(health: starting)` → `(healthy)` → `(unhealthy)` — read it right in `docker ps`.
Query it precisely:

```bash
docker inspect --format '{{.State.Health.Status}}' api            # healthy
docker inspect --format '{{json .State.Health}}' api | jq         # full probe history
```

Tune the knobs: `--interval` (how often), `--timeout` (how long to wait),
`--start-period` (grace window on boot before failures count), `--retries` (fails
in a row before "unhealthy").

## Resource limits — contain the blast radius

By default a container can use all the host's CPU and memory. Cap them:

```bash
docker run -d --name api --memory 256m --cpus 0.5 freelanceforge:prod
docker stats                     # live CPU/mem; watch it stay under the cap
docker inspect --format '{{.HostConfig.Memory}}' api    # 268435456 (256MiB)
```

If a container exceeds its memory limit, the kernel **OOM-kills** it — important to
recognize (below).

## The debugging toolkit (in order of use)

```bash
docker logs <c>                  # 1. what did it print? (usually the answer)
docker logs --tail 50 -f <c>     #    last 50 lines, then follow
docker ps -a                     # 2. what's its status / exit code?
docker inspect <c>               # 3. full state: mounts, env, network, why it died
docker exec -it <c> sh           # 4. get inside a RUNNING container and poke around
docker events                    # 5. live stream of daemon events (starts, dies, OOMs)
docker stats                     #    live resource usage
```

Reading exit codes in `docker ps -a` STATUS:

| Exit | Usually means |
|------|---------------|
| `Exited (0)` | clean finish (for a service, maybe it wasn't meant to exit) |
| `Exited (1)` | app error — read `docker logs` |
| `Exited (137)` | SIGKILL — often an **OOM kill** (128+9) or `docker kill` |
| `Exited (143)` | SIGTERM (128+15) — stopped, but didn't exit gracefully in time |

## Break it #1 — the crash loop

A container that keeps restarting because its app crashes on boot:

```bash
docker run -d --restart always --name bad freelanceforge:prod \
  uvicorn nonexistent:app --host 0.0.0.0 --port 8000
docker ps            # STATUS flickers: Restarting (1) ...
docker logs bad
```
```
ModuleNotFoundError: No module named 'nonexistent'
```

`restart: always` + a startup crash = infinite loop. The logs name the cause
immediately. **Debugging reflex:** a restarting container → `docker logs` first,
always. Fix the command/config, don't just crank up retries.

## Break it #2 — the OOM kill

```bash
docker run -d --name hog --memory 64m python:3.12-slim \
  python -c "x = bytearray(500_000_000)"     # allocate ~500MB under a 64MB cap
docker ps -a
```
```
STATUS: Exited (137)
```
```bash
docker inspect --format '{{.State.OOMKilled}}' hog     # true
```

Exit `137` + `OOMKilled=true` = the kernel killed it for exceeding memory. This is
why a container "randomly dies" under load with no app error in the logs — it's the
memory limit, not a bug. **Lesson:** when a container dies with 137 and clean logs,
suspect memory; check `OOMKilled` and raise the limit or fix the leak.

Clean up:

```bash
docker rm -f api bad hog
```

## Exercises

1. Run the production image and watch its status go from `(health: starting)` to
   `(healthy)` in `docker ps`; then read the health status via `docker inspect`.
2. Force an `Exited (137)` OOM kill with a tight `--memory` limit and a program
   that over-allocates, then confirm `OOMKilled=true` via inspect.
3. Start a container whose command is wrong so it crash-loops under
   `--restart always`, and use only `docker logs` to diagnose the cause.

Solutions: [`solutions/10.md`](../../solutions/10.md)
