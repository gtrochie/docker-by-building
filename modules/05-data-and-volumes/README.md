# Module 05 — Data & Volumes

The single most important operational fact about containers: **their filesystem is
disposable.** Learn this here, on purpose, in a safe demo — not in production with
a database.

## Mechanism

A container's writable layer lives and dies with the container. `docker rm` and
the data written inside is **gone**. To keep data, you store it *outside* the
container's lifecycle, in one of three mounts:

| Type | What it is | Use for |
|------|-----------|---------|
| **Named volume** | Docker-managed storage (`docker volume`) | databases, app data — the default choice |
| **Bind mount** | a host directory mapped in (`-v /host/path:/in/container`) | live source code in dev; host config files |
| **tmpfs** | in-memory only, never on disk | secrets/scratch you never want persisted |

Volumes are the right answer for persistence because Docker manages them, they're
portable across containers, and they survive `docker rm`.

## Do it — feel the data loss, then fix it

Write data with **no** volume, then destroy the container:

```bash
docker run -d --name db postgres:16-alpine -e POSTGRES_PASSWORD=x   # (simplified)
docker exec db sh -c 'echo "important" > /tmp/note.txt'
docker exec db cat /tmp/note.txt        # important
docker rm -f db                          # remove the container
docker run -d --name db postgres:16-alpine -e POSTGRES_PASSWORD=x
docker exec db cat /tmp/note.txt         # No such file or directory — GONE
```

The file vanished with the container. Now do it **with a named volume**:

```bash
docker volume create forgedata
docker run -d --name db -v forgedata:/data alpine sleep 3600
docker exec db sh -c 'echo "important" > /data/note.txt'
docker rm -f db                          # destroy the container...
docker run -d --name db2 -v forgedata:/data alpine sleep 3600
docker exec db2 cat /data/note.txt       # important — SURVIVED
```

Same data, different container, because it lived in the volume, not the container.

## Persisting Postgres properly

This is the real pattern for our stack — mount a volume at Postgres's data
directory so the database survives restarts and re-creations:

```bash
docker run -d --name forge-db \
  -e POSTGRES_USER=forge -e POSTGRES_PASSWORD=forge -e POSTGRES_DB=freelanceforge \
  -v forge_pgdata:/var/lib/postgresql/data \
  postgres:16-alpine
```

Now `docker rm -f forge-db` and re-run the same command — your tables and rows are
still there. `/var/lib/postgresql/data` is exactly where Postgres keeps
everything, and the volume owns that directory.

## Bind mounts — live code in development

A bind mount maps a **host** folder into the container, so edits on your machine
appear instantly inside — perfect for dev with auto-reload:

```bash
docker run --rm -p 8000:8000 \
  -v "$(pwd)/app:/app" \
  freelanceforge:dev \
  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Edit `app/main.py` on your host and uvicorn reloads inside the container. Note the
trade-off: a bind mount **overlays** the image's `/app`, so what's on your host
wins — great for dev, but not how you ship (production bakes code into the image).

## Inspecting and cleaning volumes

```bash
docker volume ls                         # list volumes
docker volume inspect forge_pgdata       # where it lives, when created
docker volume rm forgedata               # delete a volume (must be unused)
docker volume prune                      # remove all unused volumes
```

## Break it — `docker compose down -v`

The command that has eaten many a dev database:

```bash
docker compose down        # stops and removes containers; volumes SURVIVE
docker compose down -v     # ALSO deletes named volumes -> your DB data is gone
```

`-v` is convenient for a clean reset in development and **catastrophic** in
production. Likewise, an *anonymous* volume (declared in a Dockerfile `VOLUME` or
created without a name) is easy to orphan and lose track of. **Lesson:** name your
volumes, know that `-v` on `down`/`rm` deletes them, and never reflexively add
`-v` to a command touching real data.

## Exercises

1. Prove data persistence: write a file into a named volume via one container,
   remove that container, and read the file back from a **new** container using
   the same volume.
2. Run the API with a bind mount of `app/` and `--reload`, edit `main.py`, and
   confirm the change takes effect without a rebuild.
3. Show the difference between `docker compose down` and `docker compose down -v`
   by checking `docker volume ls` after each.

Solutions: [`solutions/05.md`](../../solutions/05.md)
