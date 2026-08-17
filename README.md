# Docker By Building

Learn Docker by containerizing one real app and growing it into a full stack —
running every command, inspecting what changed, and breaking things on purpose.
No abstract theory; you build understanding one layer at a time.

Companion to *PostgreSQL By Building* and *Git By Building*; same method.

## The thing you build

**FreelanceForge** — a small FastAPI quoting API (lives in `app/`). Over 12
modules you take it from "runs on my laptop" to a production-shaped, multi-service
stack (API + Postgres) defined entirely in code:

```
Module 03: one container running the API
Module 05: + persistent data in a volume
Module 06: + a private network between API and DB
Module 08: + one `docker compose up` that runs the whole stack
Module 09: + a lean, multi-stage, non-root production image
Module 11: + build, tag, push to a registry — shipped
```

## The method

Every module is the same loop:

1. **Mechanism** — what Docker is *actually doing* (the layer store, namespaces,
   the daemon), in plain language.
2. **Do it** — real commands you run.
3. **Proof** — the output to expect. Container IDs and timestamps vary by machine,
   so proofs focus on the *stable, meaningful* parts (status, sizes, responses)
   and say so where a value will differ for you.
4. **Break it** — trigger the classic failure (port in use, data lost on `rm`,
   cache not busting, permission denied) and fix it, so it's never scary later.
5. **Exercises** — with worked solutions in [`solutions/`](solutions/).

## Requirements

**Docker Engine** (or Docker Desktop). Confirm it's running:

```bash
docker version      # shows Client AND Server — both must appear
docker run hello-world
```

If `docker version` shows only a Client, the daemon isn't running — start Docker
Desktop, or `sudo systemctl start docker` on Linux. Everything here uses the
modern `docker` CLI and `docker compose` (v2, a subcommand — not the old
`docker-compose` binary).

Written and checked against Docker Engine 24+ / Compose v2. The Dockerfiles here
are linted with **hadolint** and the compose files validated with
**`docker compose config`**; the sample app is a working FastAPI service you can
also run outside Docker to compare behavior.

## Quickstart

```bash
docker build -t freelanceforge:dev .          # build the image (Module 03)
docker run --rm -p 8000:8000 freelanceforge:dev   # run it
# in another terminal:
curl localhost:8000/health                    # {"status":"ok"}
curl -X POST localhost:8000/quote -H 'Content-Type: application/json' \
     -d '{"items":[1000,2500,500]}'
# {"subtotal":4000.0,"vat_rate":0.15,"vat":600.0,"total":4600.0}
```

Or the whole stack at once (Module 08):

```bash
docker compose up --build
curl localhost:8000/db/ping                   # {"db":"ok","version":"PostgreSQL 16..."}
```

The `Makefile` wraps these as `make build`, `make run`, `make up`, `make down`,
`make prune`, etc. — run `make help`.

## Modules

| # | Module | You'll be able to… |
|---|--------|--------------------|
| 00 | What Docker is | Explain images/containers/registries; run your first container |
| 01 | Images & layers | Read the layer model, tags, digests, `history` |
| 02 | Container lifecycle | run/exec/logs/stop/rm; detached vs interactive; restart policies |
| 03 | Writing a Dockerfile | Author a correct Dockerfile and build the API image |
| 04 | Build cache & optimization | Order instructions for fast, cache-friendly rebuilds |
| 05 | Data & volumes | Persist data; choose volumes vs bind mounts vs tmpfs |
| 06 | Networking | Connect containers by name on a private network; publish ports |
| 07 | Config & env | Configure with ENV/`--env-file`/build args; keep secrets out |
| 08 | Compose | Define and run the whole multi-service stack in one file |
| 09 | Multi-stage & small images | Ship a tiny, non-root, production-grade image |
| 10 | Healthchecks & debugging | Add health checks, limits; debug a broken container |
| 11 | Registries & capstone | Tag & push to a registry; stand up and ship the full stack |

## How Docker thinks (read this once)

- An **image** is a read-only, layered snapshot of a filesystem plus metadata
  (what to run). A **container** is one running (or stopped) instance of an image
  with a thin writable layer on top. Same image → many identical containers.
- Each Dockerfile instruction that changes the filesystem creates a **layer**.
  Layers are cached and shared between images, which is why builds are fast and
  images are smaller than they look.
- The `docker` command you type is a **client** talking to the Docker **daemon**
  (the engine that actually builds images and runs containers). That client/server
  split explains a lot of Docker's behavior.
- Containers are **ephemeral**: delete one and its writable layer is gone. Data
  you want to keep goes in a **volume** (Module 05). This one fact prevents the
  most common beginner disaster.

Keep those four ideas in mind and Docker stops being magic.
