# Module 11 — Registries & Capstone

Time to **ship**: push your image to a registry so any machine (a teammate, a
server, a CI runner) can pull and run it. Then a capstone that exercises the whole
course, plus cleanup and where Docker leads next.

## Registries — how images travel

### Mechanism
A **registry** stores images; a **repository** is one named image line within it
(`youruser/freelanceforge`) with many **tags** (`:1.0`, `:latest`). Image names
encode their registry:

```
registry.example.com/namespace/name:tag
        │                │        │    └ tag (defaults to 'latest')
        │                │        └ repository name
        │                └ your user/org namespace
        └ registry host (omitted → Docker Hub)
```

`docker.io/library/nginx:alpine` is the full form of `nginx:alpine`.

### Do it — tag, log in, push

```bash
# build a versioned image
docker build -t freelanceforge:1.0 .

# tag it for YOUR registry namespace (Docker Hub user or GHCR)
docker tag freelanceforge:1.0 youruser/freelanceforge:1.0
docker tag freelanceforge:1.0 youruser/freelanceforge:latest

# authenticate (Docker Hub shown; GHCR: ghcr.io with a GitHub token)
docker login
# push both tags
docker push youruser/freelanceforge:1.0
docker push youruser/freelanceforge:latest
```
```
The push refers to repository [docker.io/youruser/freelanceforge]
5f70bf18a086: Pushed
a1b2c3d4e5f6: Layer already exists        <- shared base layers aren't re-uploaded
1.0: digest: sha256:9b2c...e41 size: 1786
```

Now anyone can run it without your source:

```bash
docker run --rm -p 8000:8000 youruser/freelanceforge:1.0
```

### Tagging strategy
- Tag with a **real version** (`:1.0`, or a git SHA) for anything deployable —
  never rely on `:latest` in production (Module 01's `latest` trap).
- Push both a version tag and `:latest` for convenience; deploy the version tag.
- Registries: **Docker Hub** (public default), **GHCR** (`ghcr.io`, great with
  GitHub Actions), or your cloud's registry (ECR/Artifact Registry/ACR).

## Capstone — ship the FreelanceForge stack

Do the whole thing end to end. No new commands — just everything in sequence.

```bash
# 1. Lint and build the production image (Modules 03, 09)
hadolint dockerfiles/Dockerfile.multistage
docker build -f dockerfiles/Dockerfile.multistage -t freelanceforge:1.0 .

# 2. Run the FULL stack with Compose (Modules 05–08)
docker compose up -d --build
docker compose ps                      # api + db, db healthy

# 3. Verify it works end to end
curl localhost:8000/health             # {"status":"ok"}
curl -X POST localhost:8000/quote -H 'Content-Type: application/json' \
     -d '{"items":[1000,2500,500]}'    # {"subtotal":4000.0,...,"total":4600.0}
curl localhost:8000/db/ping            # {"db":"ok","version":"PostgreSQL 16..."}

# 4. Prove data persists across a restart (Module 05)
docker compose restart db
curl localhost:8000/db/ping            # still ok; dbdata volume survived

# 5. Inspect health + resource use (Module 10)
docker inspect --format '{{.State.Health.Status}}' $(docker compose ps -q api)
docker stats --no-stream

# 6. Tag and push the release (this module)
docker tag freelanceforge:1.0 youruser/freelanceforge:1.0
docker login && docker push youruser/freelanceforge:1.0

# 7. Tear down cleanly (Module 05 — note: NO -v, so data is kept)
docker compose down
```

If you can run that top to bottom and explain each step, you know Docker for real
work.

## Cleanup — reclaim your disk

Docker accumulates images, stopped containers, volumes, and build cache. Reclaim
space deliberately:

```bash
docker ps -a                     # stopped containers
docker container prune           # remove stopped containers
docker image prune               # remove dangling images
docker image prune -a            # remove all images not used by a container
docker volume prune              # remove unused volumes (careful — data!)
docker builder prune             # clear build cache
docker system prune              # containers + networks + dangling images + cache
docker system prune -a --volumes # nuke everything unused, INCLUDING volumes (danger)
docker system df                 # see what's using space, before and after
```

Reach for `docker system df` first to see where space went, and be very careful
with anything touching **volumes** — that's your data.

## Where Docker leads next (orientation)

You now have single-host Docker. Running containers across *many* hosts, with
self-healing, rolling updates, autoscaling, and service discovery, is
**orchestration**:

- **Docker Compose** — one host, dev and simple prod. (You're here.)
- **Docker Swarm** — simple multi-host clustering using Compose-like files.
- **Kubernetes** — the industry standard for large-scale orchestration. Your
  images don't change; what changes is the layer that schedules and manages them.

The image you built and pushed is the exact artifact every one of those runs.
That's why "build once, run anywhere" holds all the way from `docker run` on your
laptop to a Kubernetes cluster.

## Exercises

1. Build a `:1.0` image, tag it for a registry namespace, and (against Docker Hub
   or GHCR) push both `:1.0` and `:latest`. Confirm the second push reports
   "Layer already exists" for shared layers.
2. Run the full capstone sequence and get all three `curl` checks passing, then
   prove the DB data survived a `docker compose restart db`.
3. Use `docker system df` before and after a `docker system prune` to quantify how
   much space you reclaimed.

Solutions: [`solutions/11.md`](../../solutions/11.md)
