# Module 02 — Container Lifecycle

## Mechanism

A container is a process (plus an isolated filesystem, network, and PID space)
started from an image. Its life is a small state machine:

```
       docker run
  (none) ────────► running ──stop──► stopped ──rm──► (gone)
                     ▲   │              │
                     └start────────────┘
```

Key idea: **when the container's main process exits, the container stops.** A
container isn't a little VM you log into — it exists to run *one* foreground
process (its `CMD`). Understand that and half of Docker's "why did my container
immediately exit?" confusion disappears.

## The essential run flags

```
-d            detached: run in the background, print the container ID
-it           interactive + TTY: for shells and interactive programs
--rm          auto-remove the container when it exits (no stopped clutter)
--name NAME   give it a stable name instead of a random one
-p H:C        publish host port H to container port C
-e K=V        set an environment variable
```

## Do it

Foreground vs detached:

```bash
# foreground: your terminal is attached to the process; Ctrl-C stops it
docker run --rm -p 8080:80 nginx:alpine

# detached: runs in the background, gives you the prompt back
docker run -d --rm -p 8080:80 --name web nginx:alpine
```

Look at a running container and read its output:

```bash
docker ps                     # is it up?
docker logs web               # what has it printed?
docker logs -f web            # follow live (Ctrl-C to stop following, not the container)
```

Run a command **inside** a running container — the single most useful debugging
tool in Docker:

```bash
docker exec -it web sh        # open a shell inside 'web'
# now you're in the container:
ls /usr/share/nginx/html
cat /etc/os-release
exit
```

`exec` starts an *additional* process in the container; it doesn't disturb the
main one. Use it to poke around, check files, or run a one-off command:

```bash
docker exec web nginx -v      # run a single command, no shell
```

## Stopping, starting, removing

```bash
docker stop web        # SIGTERM, then SIGKILL after ~10s grace period
docker ps -a           # still listed, STATUS = Exited
docker start web       # bring the same container back
docker rm -f web       # force-remove (stop + delete)
```

`stop` is graceful (lets the app shut down); `kill` is immediate. `rm` deletes
the container **and its writable layer** — anything written inside that wasn't in
a volume is gone (Module 05 fixes that).

## Restart policies — surviving crashes and reboots

By default a stopped container stays stopped. For anything long-running you want
it to come back automatically:

```bash
docker run -d --restart unless-stopped --name web nginx:alpine
```

| Policy | Behavior |
|--------|----------|
| `no` (default) | never restart |
| `on-failure[:N]` | restart only on non-zero exit, up to N times |
| `always` | restart always, even after a daemon/host reboot |
| `unless-stopped` | like `always`, but respects a manual `docker stop` |

`unless-stopped` is the usual choice for services.

## Break it — the container that "won't stay running"

A classic beginner surprise:

```bash
docker run -d --name box ubuntu
docker ps                 # ...nothing. Where did it go?
docker ps -a              # STATUS: Exited (0)   — it exited immediately
```

Why? `ubuntu`'s default command is essentially a shell, and with no terminal
attached and nothing to do, the process exits instantly — so the container stops.
A container needs a **foreground process that keeps running**. Give it one:

```bash
docker run -d --name box ubuntu sleep 3600     # now it has something to do
docker ps                                       # Up, running for an hour
docker rm -f box
```

This is exactly why our API container works: `uvicorn` runs in the foreground and
stays up, so the container stays up. **Lesson:** if a container exits immediately,
its main process finished — check the `CMD` and `docker logs`.

## Inspecting deeply

```bash
docker inspect web                       # full JSON: config, network, mounts, state
docker inspect --format '{{.State.Status}}' web        # just one field
docker inspect --format '{{.NetworkSettings.IPAddress}}' web
docker stats                             # live CPU/memory per container
docker top web                           # processes running inside
```

## Exercises

1. Run an nginx container detached with `--restart unless-stopped`. Kill its main
   process with `docker kill` and confirm the restart policy brings it back.
2. Start a `python:3.12-slim` container that stays alive, `exec` into it, and run
   `python3 --version` inside — two different ways (interactive shell, and a
   single `exec` command).
3. Run a container that exits immediately, then use `docker ps -a` and
   `docker logs` to explain *why* it exited.

Solutions: [`solutions/02.md`](../../solutions/02.md)
