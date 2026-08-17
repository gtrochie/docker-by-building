# Module 00 — What Docker Is

## Mechanism

Docker packages an app **with everything it needs to run** — runtime, libraries,
system tools — into a single artifact that runs the same on any machine with
Docker. No more "works on my laptop."

Three words you must not confuse:

- **Image** — a read-only template: a layered filesystem snapshot + metadata
  saying what to run. Think "a class."
- **Container** — a running (or stopped) instance of an image, with a thin
  writable layer on top. Think "an object." One image → many containers.
- **Registry** — a server that stores images (Docker Hub is the default public
  one). `pull` downloads, `push` uploads.

And one architectural fact that explains Docker's whole feel: the `docker`
command is a **client** that sends requests to the Docker **daemon** (`dockerd`),
a background engine that does the real work of building images and running
containers. When people say "is Docker running?" they mean the daemon.

```
  you type: docker run ...
      │
      ▼
  docker CLI  ──►  Docker daemon (dockerd)  ──►  pulls image from registry,
   (client)          (the engine)                 creates + starts container
```

Containers are **not** virtual machines. A VM ships a whole guest OS; a container
shares the host kernel and just isolates the process (via Linux namespaces and
cgroups). That's why containers start in milliseconds and are small.

## Do it

Confirm the daemon is up — you must see **both** Client and Server:

```bash
docker version
```
```
Client: Docker Engine - Community
 Version:  24.x.x
 ...
Server: Docker Engine - Community      <- if this section is missing, the daemon is down
 Version:  24.x.x
```

Run your first container:

```bash
docker run hello-world
```
```
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
...
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

Read what just happened, because it's the whole model in miniature: the daemon
didn't find the image locally → **pulled** it from Docker Hub → **created** a
container from it → **ran** it (it printed the message) → the process exited.

Now run something long-lived and interact with it:

```bash
docker run -d -p 8080:80 --name web nginx:alpine   # -d = detached (background)
docker ps                                           # list running containers
```
```
CONTAINER ID   IMAGE          COMMAND                  STATUS         PORTS                  NAMES
a1b2c3d4e5f6   nginx:alpine   "/docker-entrypoint.…"   Up 3 seconds   0.0.0.0:8080->80/tcp   web
```

Visit <http://localhost:8080> — the nginx welcome page is served from inside the
container. `-p 8080:80` **published** container port 80 to host port 8080 (left =
host, right = container; you'll use this constantly).

Stop and remove it:

```bash
docker stop web
docker rm web
```

(Container IDs and the exact `STATUS` text will differ on your machine — that's
expected. The shape of the output is what matters.)

## The container lifecycle

```
docker run   = create + start           docker stop   = graceful stop (SIGTERM)
docker ps    = running containers        docker start  = start a stopped one
docker ps -a = ALL (incl. stopped)       docker rm     = delete a stopped one
docker logs  = its output                docker exec   = run a command inside it
```

A container in `docker ps -a` with status `Exited (0)` isn't an error — it ran
and finished. Status `Exited (1)` (or other non-zero) means the main process
crashed; `docker logs <name>` tells you why.

## Break it — the port clash

Try to run two containers on the same host port:

```bash
docker run -d -p 8080:80 --name web1 nginx:alpine
docker run -d -p 8080:80 --name web2 nginx:alpine
```
```
docker: Error response from daemon: driver failed programming external
connectivity on endpoint web2: Bind for 0.0.0.0:8080 failed: port is already
allocated.
```

Only one process can own a host port. This is the #1 beginner error. Fix by
publishing to a different host port (the container port can stay 80):

```bash
docker run -d -p 8081:80 --name web2 nginx:alpine   # host 8081 now
```

Clean up:

```bash
docker rm -f web1 web2      # -f force-removes even running containers
```

## Exercises

1. Run `hello-world`, then find the stopped container with `docker ps -a` and
   remove it by name or ID.
2. Run an nginx container detached on host port 9000, confirm it serves a page,
   then view its logs.
3. Explain in one sentence each: image vs container, and daemon vs client. (Check
   yourself against the Mechanism section.)

Solutions: [`solutions/00.md`](../../solutions/00.md)
