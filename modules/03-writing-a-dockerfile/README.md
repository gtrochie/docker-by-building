# Module 03 — Writing a Dockerfile

Now you build your **own** image: the FreelanceForge API.

## Mechanism

A `Dockerfile` is a recipe. Each instruction runs in order and (if it changes the
filesystem) produces a **layer**. `docker build` sends your project folder — the
**build context** — to the daemon, then executes the recipe to produce an image.

The instructions you'll use constantly:

| Instruction | Meaning |
|-------------|---------|
| `FROM` | the base image to start from |
| `WORKDIR` | set (and create) the working directory for later instructions |
| `COPY` | copy files from the build context into the image |
| `RUN` | execute a command **at build time** (e.g. install deps) → new layer |
| `ENV` | set an environment variable (persists into the running container) |
| `EXPOSE` | document which port the app listens on (metadata, not a firewall) |
| `CMD` | the default command to run **when the container starts** |

`RUN` happens while **building** the image; `CMD` happens when **running** a
container. Mixing these two up is the most common Dockerfile misconception.

## Do it — the Dockerfile

This is the `Dockerfile` at the repo root:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Copy deps FIRST so this layer caches unless requirements change (Module 04).
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Then copy the source.
COPY app/ .

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Line by line:

- `FROM python:3.12-slim` — a small official Python base (pinned tag, not `latest`).
- `ENV PYTHONUNBUFFERED=1` — logs appear immediately instead of being buffered
  (so `docker logs` is useful). `PYTHONDONTWRITEBYTECODE=1` skips `.pyc` clutter.
- `WORKDIR /app` — all following commands run in `/app`; it's created if missing.
- `COPY requirements.txt` then `RUN pip install` **before** copying code — this
  ordering is the key to fast rebuilds (Module 04). Requirements change rarely, so
  the expensive install layer stays cached.
- `COPY app/ .` — copy the source in.
- `EXPOSE 8000` — documents the port (you still need `-p` to publish it).
- `CMD [...]` — **JSON array form** ("exec form"). Runs uvicorn as the container's
  main process, in the foreground, so the container stays up.

## Build and run

```bash
docker build -t freelanceforge:dev .
```
```
[+] Building 12.3s (10/10) FINISHED
 => [internal] load build definition from Dockerfile
 => [1/5] FROM docker.io/library/python:3.12-slim
 => [2/5] WORKDIR /app
 => [3/5] COPY app/requirements.txt .
 => [4/5] RUN pip install --no-cache-dir -r requirements.txt
 => [5/5] COPY app/ .
 => exporting to image
 => => naming to docker.io/library/freelanceforge:dev
```

The `[n/5]` steps are your layers being built. Run it and hit real endpoints:

```bash
docker run --rm -p 8000:8000 freelanceforge:dev
```
```bash
# another terminal:
curl localhost:8000/health
```
```
{"status":"ok"}
```
```bash
curl -X POST localhost:8000/quote -H 'Content-Type: application/json' \
     -d '{"items":[1000,2500,500]}'
```
```
{"subtotal":4000.0,"vat_rate":0.15,"vat":600.0,"total":4600.0}
```

(Those JSON responses are the real app output — verified by running the app
directly.) You just built and ran your own containerized service.

## .dockerignore — keep the context clean

`COPY . .` would copy `.git/`, `__pycache__/`, virtualenvs, and secrets into your
image — bloating it and leaking things. A `.dockerignore` (like `.gitignore`)
excludes them from the build context:

```
.git
**/__pycache__/
.venv/
.env
modules/
```

Smaller context = faster builds and smaller, safer images.

## CMD vs ENTRYPOINT (and exec vs shell form)

- **`CMD`** sets the default command; it's easily overridden at `docker run`.
- **`ENTRYPOINT`** sets a fixed executable; `CMD` (or run args) become its
  arguments. Use `ENTRYPOINT` when the container *is* one tool.
- Always prefer **exec form** `["cmd", "arg"]` over **shell form** `cmd arg`.
  Shell form wraps your command in `/bin/sh -c`, which breaks signal handling —
  your app won't receive `SIGTERM` on `docker stop` and will be killed hard.

## Break it — lint the mistakes

Here's a Dockerfile full of the classic errors:

```dockerfile
FROM python
RUN apt-get update
RUN apt-get install -y curl
ADD . /app
WORKDIR /app
RUN pip install -r requirements.txt
CMD uvicorn main:app --host 0.0.0.0
```

Run **hadolint** (a Dockerfile linter) on it and it flags every one:

```
DL3006 warning: Always tag the version of an image explicitly   (FROM python -> python:3.12-slim)
DL3008 warning: Pin versions in apt-get install
DL3009 info:    Delete the apt-get lists after installing something
DL3015 info:    Avoid additional packages: use --no-install-recommends
DL3020 error:   Use COPY instead of ADD for files and folders
DL3042 warning: Avoid pip cache: use pip install --no-cache-dir
DL3025 warning: Use JSON notation for CMD (exec form)
DL3059 info:    Multiple consecutive RUN instructions; consolidate
```

What each teaches:

- **untagged `FROM python`** → non-reproducible; pin `python:3.12-slim`.
- **`ADD . /app`** → `ADD` has surprising behavior (auto-extracts tars, fetches
  URLs); use `COPY` for plain files.
- **separate `apt-get update` / `install`** → can cache a stale package list;
  combine them in one `RUN` and clean up (`&& rm -rf /var/lib/apt/lists/*`).
- **pip without `--no-cache-dir`** → leaves a cache in the image, wasting space.
- **shell-form `CMD`** → breaks `SIGTERM` handling; use the JSON array form.

The version at the repo root fixes all of these — it's hadolint-clean. Get in the
habit of linting your Dockerfiles; it catches real problems before they ship.

## Exercises

1. Add a `curl`-based tool to the image by installing it correctly in a **single**
   `RUN` (update + install + clean lists), and lint to confirm no warnings.
2. Change the `CMD` so the container runs with `--reload` for development, then
   override that command at `docker run` time without rebuilding.
3. Rewrite the "bad" Dockerfile above into a clean one and check it passes
   hadolint with no errors.

Solutions: [`solutions/03.md`](../../solutions/03.md)
