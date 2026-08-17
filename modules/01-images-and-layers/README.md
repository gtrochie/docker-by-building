# Module 01 — Images & Layers

## Mechanism

An image is built from **layers** stacked on top of each other. Each layer is a
set of filesystem changes. When you run a container, Docker stacks the image's
read-only layers and adds one thin **writable layer** on top (a "union
filesystem"). Two consequences worth internalizing:

- **Layers are shared and cached.** If ten images all start `FROM python:3.12-slim`,
  that base layer is stored **once** on disk and reused. This is why images are
  smaller on disk than their listed sizes suggest, and why builds are fast.
- **Images are identified two ways:** a human **tag** (`nginx:alpine`) that can
  move, and an immutable **digest** (`sha256:…`) that always refers to the exact
  same bytes. `latest` is just a tag, not "the newest" — it's whatever was last
  tagged `latest`.

## Do it

Pull an image and list what you have:

```bash
docker pull python:3.12-slim
docker images
```
```
REPOSITORY   TAG          IMAGE ID       CREATED       SIZE
python       3.12-slim    a1b2c3d4e5f6   2 weeks ago   130MB
nginx        alpine       f6e5d4c3b2a1   3 weeks ago   48MB
hello-world  latest       9c7a54a9a43c   6 months ago  13.3kB
```

Inspect the **layers** of an image and how each was built:

```bash
docker history python:3.12-slim
```
```
IMAGE          CREATED       CREATED BY                                      SIZE
a1b2c3d4e5f6   2 weeks ago   CMD ["python3"]                                 0B
<missing>      2 weeks ago   RUN set -eux; ... pip install ...               12MB
<missing>      2 weeks ago   ENV PYTHON_VERSION=3.12.x                        0B
<missing>      2 weeks ago   /bin/sh -c #(nop) ADD file:... in /              77MB
...
```

Each row is a layer. `0B` layers are metadata-only (like `ENV`, `CMD`) — they
cost nothing. `<missing>` just means that layer has no separate tag of its own.

## Tags and digests

The same image can wear several tags:

```bash
docker tag python:3.12-slim myteam/python:pinned    # add another name (no copy)
docker images | grep python
```

Both names point at the **same IMAGE ID** — a tag is a label, not a copy. To pin
a build so it can never drift, reference the digest instead of a tag:

```bash
docker inspect --format='{{index .RepoDigests 0}}' python:3.12-slim
```
```
python@sha256:9b2c...e41
```

Using `FROM python@sha256:9b2c...` in a Dockerfile guarantees byte-for-byte the
same base forever; `FROM python:3.12-slim` may quietly change when the tag is
re-published. Teams pin digests for reproducible production builds.

## Proof — layer sharing is real

Pull two images that share a base and watch the second reuse layers:

```bash
docker pull python:3.12-slim     # downloads several layers
docker pull python:3.12          # shares the lower layers; only pulls the difference
```
```
3.12: Pulling from library/python
a1b2c3d4: Already exists          <- shared layer, not re-downloaded
e5f6a7b8: Pull complete           <- only the new layers download
```

`Already exists` is the layer cache doing its job.

## Break it — the `latest` trap

`latest` feels like "newest" but isn't:

```bash
docker pull nginx                # same as nginx:latest
docker pull nginx:alpine
docker images nginx
```
```
REPOSITORY   TAG      IMAGE ID       SIZE
nginx        latest   aaaa1111       188MB     <- the full Debian-based image
nginx        alpine   bbbb2222       48MB      <- a totally different, smaller image
```

`nginx:latest` and `nginx:alpine` are **different images**, not versions of one.
Relying on `latest` means your build can change under you without warning.
**Lesson:** always pin a real tag (or digest). `latest` is for demos, not
production.

## Cleaning up images

```bash
docker rmi hello-world              # remove one image
docker image prune                  # remove "dangling" (untagged) images
docker image prune -a               # remove ALL images not used by a container
docker system df                    # see how much space images/containers/volumes use
```

## Exercises

1. Pull `alpine:3.20`, then use `docker history` to count how many layers it has
   and identify which single layer holds essentially all its size.
2. Give an existing image a second tag, and prove with `docker images` that both
   tags share one IMAGE ID.
3. Find the digest of `nginx:alpine` and explain when you'd reference an image by
   digest instead of tag.

Solutions: [`solutions/01.md`](../../solutions/01.md)
