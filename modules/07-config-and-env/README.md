# Module 07 — Config & Environment

The same image should run in dev, staging, and prod **without rebuilding** — only
its configuration changes. That's the "build once, run anywhere" promise, and it
depends on getting config and secrets right.

## Mechanism

- **`ENV` (Dockerfile)** — sets a variable baked into the image as a default.
  Present at build time and in every container run from the image.
- **`-e KEY=VALUE` / `--env-file` (run time)** — sets or overrides variables when
  you start a container. This is how you configure per-environment.
- **`ARG` (Dockerfile)** — a **build-time** variable, passed with
  `--build-arg`. Available only during `docker build`, **not** in the running
  container. Use for build options (versions, flags), never for runtime config.

Rule of thumb (the "12-factor" principle): **config comes from the environment,
not the image.** The image is identical everywhere; env vars make it behave
differently.

## Do it — override config at run time

Our app reads `APP_ENV` and `VAT_RATE` from the environment (with defaults). Same
image, different behavior:

```bash
docker run --rm -p 8000:8000 freelanceforge:dev
curl localhost:8000/
# {"app":"FreelanceForge","env":"development","vat_rate":0.15}   <- defaults

docker run --rm -p 8000:8000 -e APP_ENV=production -e VAT_RATE=0.20 freelanceforge:dev
curl localhost:8000/
# {"app":"FreelanceForge","env":"production","vat_rate":0.2}     <- overridden, no rebuild
```

## Env files — keep config in one place

Listing many `-e` flags is tedious and leaks into shell history. Use a file:

```bash
# forge.env
APP_ENV=production
VAT_RATE=0.15
DATABASE_URL=postgresql://forge:forge@db:5432/freelanceforge
```
```bash
docker run --rm -p 8000:8000 --env-file forge.env freelanceforge:dev
```

Add `forge.env` (and `.env`) to `.gitignore` and `.dockerignore` so config and
secrets never get committed or copied into images.

## Build args vs runtime env

```dockerfile
ARG PYTHON_VERSION=3.12          # build-time only
FROM python:${PYTHON_VERSION}-slim
ENV APP_ENV=production            # runtime default, overridable with -e
```
```bash
docker build --build-arg PYTHON_VERSION=3.11 -t freelanceforge:py311 .
```

`PYTHON_VERSION` shapes the build; it's gone by run time. `APP_ENV` is a runtime
default you can override per container. Choosing the wrong one is a common mistake:
if you need to change it *per environment*, it's runtime env, not a build arg.

## Break it — a secret baked into the image

The tempting-but-wrong way to give the app a secret:

```dockerfile
ENV DATABASE_PASSWORD=super-secret-123      # DON'T
```

or

```dockerfile
RUN echo "api_key=sk-live-abc123" > /app/secrets.txt   # DON'T
```

Anyone with the image can read it — it's permanently in a layer:

```bash
docker history --no-trunc freelanceforge:dev | grep -i password
docker run --rm freelanceforge:dev printenv DATABASE_PASSWORD
# super-secret-123        <- exposed to anyone who can run the image
```

Even if a later layer deletes the file, it still exists in the earlier layer
(Module 04's cumulative-layers rule). **Secrets in images leak.** Do instead:

- Pass secrets at **run time** via `-e` / `--env-file` (kept out of the image).
- For builds that need a secret (e.g. a private package token), use BuildKit
  secrets so it's never stored in a layer:
  ```dockerfile
  RUN --mount=type=secret,id=pip_token \
      pip install --extra-index-url "https://$(cat /run/secrets/pip_token)@..." ...
  ```
  ```bash
  docker build --secret id=pip_token,src=./token.txt -t app .
  ```
- In production, use your platform's secret manager (Compose secrets, Kubernetes
  Secrets, cloud secret stores) and inject at run time.

**Lesson:** the image is public-ish and immutable — treat everything in it as
readable. Config and secrets belong in the environment, injected when the
container runs.

## Exercises

1. Run the API three times from the **same image** with `VAT_RATE` set to 0.0,
   0.15, and 0.20, and confirm `GET /` reflects each — no rebuild.
2. Move all config into a `forge.env` file and start the container with
   `--env-file`. Verify `.env` patterns are in `.dockerignore`.
3. Demonstrate the leak: bake a fake secret with `ENV`, then extract it from a
   running container with `printenv` and from the image with `docker history`.
   Then remove it and pass it via `-e` instead.

Solutions: [`solutions/07.md`](../../solutions/07.md)
