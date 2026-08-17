# Module 04 — Build Cache & Optimization

Why does the *second* `docker build` take 12 seconds but a later one take 0.5s —
until you change one line and it's slow again? Because of the **layer cache**.
Understanding it is the difference between 30-second and 3-second edit-build loops.

## Mechanism

`docker build` executes instructions top to bottom. For each instruction it asks:
"have I built this exact instruction, with the exact same inputs, before?"

- **Yes** → reuse the cached layer (`CACHED`), instantly.
- **No** → run it, produce a new layer, **and invalidate the cache for every
  instruction after it.**

That last part is the whole game: **once a layer's cache is busted, everything
below it rebuilds too.** So the *order* of instructions decides your rebuild
speed. Put things that change rarely (installing dependencies) **before** things
that change constantly (your source code).

For `COPY`, the cache key includes the **contents** of the copied files. So
`COPY app/ .` busts its cache the moment any source file changes — which is every
edit.

## Do it — see the cache work

Build once, then build again with no changes:

```bash
docker build -t freelanceforge:dev .      # first build: runs every step
docker build -t freelanceforge:dev .      # second build: everything CACHED
```
```
 => CACHED [2/5] WORKDIR /app
 => CACHED [3/5] COPY app/requirements.txt .
 => CACHED [4/5] RUN pip install --no-cache-dir -r requirements.txt
 => CACHED [5/5] COPY app/ .
 => exporting to image
Build finished in 0.4s
```

Every step `CACHED` → near-instant.

## Proof — order matters

Now edit a source file (not requirements) and rebuild:

```bash
echo "# a tiny change" >> app/main.py
docker build -t freelanceforge:dev .
```
```
 => CACHED [3/5] COPY app/requirements.txt .
 => CACHED [4/5] RUN pip install --no-cache-dir -r requirements.txt   <- still cached! 
 => [5/5] COPY app/ .                                                  <- only this reruns
```

The expensive `pip install` stayed cached because `requirements.txt` didn't
change — that's the payoff of copying requirements **before** the source. The only
step that reran was copying the changed code.

Contrast the **wrong** order:

```dockerfile
# BAD: copy everything first
COPY app/ .
RUN pip install --no-cache-dir -r requirements.txt
```

Here, editing *any* source file changes the `COPY app/ .` layer, which busts the
cache for the `pip install` below it — so **every code change reinstalls all
dependencies.** Same instructions, drastically worse loop. Order is everything.

## Cache-busting on purpose

Sometimes you *want* to bypass the cache — e.g. to pull fresh apt packages:

```bash
docker build --no-cache -t freelanceforge:dev .   # rebuild everything from scratch
```

And a subtle trap: `RUN apt-get update` in its own layer can be cached while a
later `apt-get install` in another layer isn't — installing stale package
references. Always combine them in one `RUN`:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
```

## BuildKit and smarter caching

Modern Docker uses **BuildKit** by default. Two high-value features:

- **`--mount=type=cache`** keeps a package cache *between* builds without baking
  it into the image — great for pip/npm/apt:
  ```dockerfile
  RUN --mount=type=cache,target=/root/.cache/pip \
      pip install -r requirements.txt
  ```
- **Parallel stages** — independent build stages run concurrently (Module 09).

Enable it explicitly if needed with `DOCKER_BUILDKIT=1 docker build ...` (it's on
by default in current Docker).

## Smaller images, faster everything

Image size affects pull time, push time, disk, and attack surface. Levers
(deepened in Module 09):

- **Pick a slim base**: `python:3.12-slim` (~130MB) vs `python:3.12` (~1GB).
- **Combine `RUN`s and clean up in the same layer** — deleting files in a *later*
  layer doesn't shrink the image; the bytes still live in the earlier layer.
- **`--no-cache-dir`** for pip, `rm -rf /var/lib/apt/lists/*` for apt.
- **`.dockerignore`** so junk never enters the context.
- **Multi-stage builds** (Module 09) — build in a fat image, ship only the result.

## Break it — the "delete doesn't shrink" surprise

```dockerfile
RUN pip install --no-cache-dir big-package
RUN pip uninstall -y big-package        # trying to slim the image
```

The final image is **not** smaller. Each `RUN` is a separate layer; the uninstall
adds a layer that hides the files, but the install layer beneath still contains
them, and image size is the sum of all layers. To actually save space, never let
the bytes land in a committed layer in the first place — do install-and-cleanup in
**one** `RUN`, or use multi-stage builds. **Lesson:** you can't delete your way to
a smaller image across layers; size is cumulative.

## Exercises

1. Build the image, then rebuild after editing only `main.py`, and confirm from
   the output that the `pip install` layer stayed `CACHED`.
2. Deliberately reorder the Dockerfile to copy source before installing deps,
   rebuild after a code edit, and observe dependencies reinstalling. Then revert.
3. Add a `--mount=type=cache` to the pip install step and describe what it changes
   about repeated builds.

Solutions: [`solutions/04.md`](../../solutions/04.md)
