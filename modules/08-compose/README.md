# Module 08 — Docker Compose

Everything from Modules 03–07 — build the image, run it, add a volume, put it on a
network with Postgres, inject config — collapses into **one file** and **one
command**. This is where it all comes together.

## Mechanism

**Compose** describes a multi-container app declaratively in `compose.yaml`. You
define *services* (containers), and Compose creates them, wires up a shared
network (so they reach each other by service name), manages volumes, and starts
everything in dependency order. `docker compose up` = "make reality match this
file."

Note: it's `docker compose` (a subcommand of Docker, v2), not the old standalone
`docker-compose`.

## Do it — the whole stack

This is `compose.yaml` at the repo root:

```yaml
services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      APP_ENV: production
      VAT_RATE: "0.15"
      DATABASE_URL: postgresql://forge:forge@db:5432/freelanceforge
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: forge
      POSTGRES_PASSWORD: forge
      POSTGRES_DB: freelanceforge
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U forge -d freelanceforge"]
      interval: 5s
      timeout: 3s
      retries: 5
    restart: unless-stopped

volumes:
  dbdata:
```

Everything you learned by hand is here declaratively: `build: .` (Module 03),
`dbdata` volume (05), the implicit shared network + `db` hostname (06),
`environment` config (07). Validate it without even running it:

```bash
docker compose config          # parses, merges, and prints the normalized spec
docker compose config --services
```
```
db
api
```

Bring it all up:

```bash
docker compose up --build
```
```
 ✔ Network freelanceforge_default   Created
 ✔ Volume  freelanceforge_dbdata    Created
 ✔ Container freelanceforge-db-1    Healthy
 ✔ Container freelanceforge-api-1   Started
```

Then hit the API, which now reaches Postgres by the service name `db`:

```bash
curl localhost:8000/db/ping
```
```
{"db":"ok","version":"PostgreSQL 16.x on x86_64-pc-linux-musl..."}
```

One command stood up an API and a database, networked and health-gated. That's the
whole point of Compose.

## The everyday commands

```bash
docker compose up -d           # start in the background
docker compose ps              # status of this project's services
docker compose logs -f api     # follow one service's logs
docker compose exec api sh     # shell into the running api service
docker compose build           # (re)build images
docker compose down            # stop + remove containers and network (volumes kept)
docker compose down -v         # ...also delete named volumes (data gone — Module 05)
docker compose up -d --scale api=3   # run 3 replicas of the api service
```

## depends_on and healthchecks — why order isn't enough

`depends_on` controls **start order**, but by default it only waits for the
container to *start*, not for the app inside to be *ready*. Postgres takes a second
or two to accept connections after its container starts. Without a readiness gate,
the API can start first and crash trying to connect.

The fix is the healthcheck + `condition: service_healthy` above: Compose runs
`pg_isready` until it passes, and only *then* starts the API. `depends_on` +
`condition: service_healthy` is the correct "wait for the database" pattern.

## Overrides — dev vs prod without duplication

Compose merges files. Keep a base `compose.yaml` and layer a
`compose.override.yaml` for dev (bind-mount source, enable `--reload`):

```yaml
# compose.override.yaml (auto-merged by `docker compose up`)
services:
  api:
    volumes:
      - ./app:/app          # live code (Module 05)
    command: ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
    environment:
      APP_ENV: development
```

`docker compose up` uses base + override (dev). In prod you point at just the base
with `-f compose.yaml`. Same stack, environment-specific behavior, no copy-paste.

## Break it — the readiness race

Remove the healthcheck gate and use a plain dependency:

```yaml
  api:
    depends_on:
      - db            # start order only, NOT readiness
```

Now `docker compose up` may produce:

```
freelanceforge-api-1  | {"db":"error","detail":"connection refused ... db:5432"}
```

The API started, tried to connect before Postgres was accepting connections, and
failed. Two proper fixes: (1) the `condition: service_healthy` gate shown above, or
(2) make the app **retry** its DB connection on startup (belt-and-suspenders — real
services do both, since a DB can also drop mid-run). **Lesson:** "started" ≠
"ready"; gate on health, and make apps resilient to a DB that isn't up yet.

## Exercises

1. Bring the full stack up and get `curl localhost:8000/db/ping` to return
   `"db":"ok"`. Then `docker compose down` and confirm with `docker volume ls`
   that `dbdata` survived.
2. Add a `compose.override.yaml` that bind-mounts `app/` and enables `--reload`;
   confirm code edits take effect without rebuilding.
3. Break readiness by switching to plain `depends_on: [db]`, observe the failure
   in the logs, then restore the healthcheck gate.

Solutions: [`solutions/08.md`](../../solutions/08.md)
