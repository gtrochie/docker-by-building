# Module 06 — Networking

How does the API container talk to the database container? Not by IP addresses you
hard-code — by **name, on a shared network.** This module makes that concrete.

## Mechanism

Docker gives containers their own network namespace. Containers communicate over
**networks**:

- The default `bridge` network exists, but containers on it can only reach each
  other by **IP**, not name — not what you want.
- A **user-defined bridge network** adds automatic **DNS**: every container can
  reach every other by its **container/service name**. This is the foundation of
  multi-container apps (and Compose sets one up for you automatically).

Two kinds of "port":

- **Internal**: containers on the same network reach each other on the container's
  own port (e.g. Postgres on `5432`) — no publishing needed.
- **Published** (`-p H:C`): exposes a container port to the **host** so *you* can
  reach it from your laptop. You only publish what needs to be reached from
  outside; internal services (like the DB) often shouldn't be published at all.

## Do it — connect API to DB by name

Create a network and put both containers on it:

```bash
docker network create forge-net

# database — on the network, NOT published to the host (internal only)
docker run -d --name db --network forge-net \
  -e POSTGRES_USER=forge -e POSTGRES_PASSWORD=forge -e POSTGRES_DB=freelanceforge \
  postgres:16-alpine

# api — on the same network; reaches the DB at hostname 'db'
docker run -d --name api --network forge-net -p 8000:8000 \
  -e DATABASE_URL=postgresql://forge:forge@db:5432/freelanceforge \
  freelanceforge:dev
```

The magic is `@db:5432` in the URL: **`db` is the container's name**, and Docker's
DNS on `forge-net` resolves it to the database container's IP. Verify the API can
reach the DB:

```bash
curl localhost:8000/db/ping
```
```
{"db":"ok","version":"PostgreSQL 16.x on x86_64-pc-linux-musl..."}
```

The API is published (`-p 8000:8000`) so *you* can curl it; the DB is **not**
published — it's reachable only by containers on `forge-net`, which is exactly how
you want a database exposed.

Prove the name resolution directly:

```bash
docker exec api getent hosts db      # resolves 'db' to an IP on the network
docker exec api sh -c 'nc -z db 5432 && echo "DB reachable"'
```

## Inspecting networks

```bash
docker network ls                        # list networks
docker network inspect forge-net         # which containers are attached, subnet, IPs
docker network connect forge-net web     # attach a running container to a network
docker network disconnect forge-net web
```

## The `localhost` trap (read this twice)

Inside a container, `localhost` means **that container itself**, not your host and
not another container. Two consequences that bite everyone:

- From inside the `api` container, `localhost:5432` is the *api* container, where
  nothing is listening → connection refused. The DB is at `db:5432`, not
  `localhost:5432`.
- To reach a service running on your **host machine** from inside a container, use
  the special name `host.docker.internal` (Docker Desktop) rather than
  `localhost`.

## Break it — same host, no shared network

Put the DB and API on **different** networks (or the default bridge) and watch DNS
fail:

```bash
docker run -d --name db2 postgres:16-alpine -e POSTGRES_PASSWORD=x   # default bridge
docker run -d --name api2 -p 8001:8000 \
  -e DATABASE_URL=postgresql://forge:forge@db2:5432/freelanceforge \
  freelanceforge:dev
curl localhost:8001/db/ping
```
```
{"db":"error","detail":"could not translate host name \"db2\" to address: ..."}
```

`db2` can't be resolved because `api2` and `db2` don't share a user-defined
network. The fix is always the same: **put communicating containers on the same
user-defined network**, then address each other by name. (Compose does this for
you — every service in a compose file lands on one network and can reach the
others by service name. That's why the compose version "just works.")

Clean up:

```bash
docker rm -f db api db2 api2
docker network rm forge-net
```

## Exercises

1. Create a network, run Postgres on it (unpublished) and the API on it
   (published), and get `curl localhost:8000/db/ping` to return `"db":"ok"`.
2. From inside the API container, use `getent hosts db` and a port check to prove
   the DB name resolves and the port is open.
3. Reproduce the "could not translate host name" error by leaving the two
   containers off a shared network, then fix it by connecting them to one.

Solutions: [`solutions/06.md`](../../solutions/06.md)
