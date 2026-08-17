# Module 09 — Multi-stage Builds & Small Images

The image you build to *compile* an app is fat (compilers, headers, caches). The
image you *ship* should be lean (just the runtime + your app). **Multi-stage
builds** let you have both in one Dockerfile: build in a big stage, copy only the
result into a small final stage.

## Mechanism

A Dockerfile can contain **multiple `FROM` stages**. Only the **last** stage
becomes your image; earlier stages are scratch space. `COPY --from=<stage>` pulls
just the artifacts you want out of an earlier stage, leaving all the build tooling
behind. Result: a small, clean final image with no compilers or caches in it.

## Do it — the production Dockerfile

`dockerfiles/Dockerfile.multistage` (hadolint-clean):

```dockerfile
# ---- Stage 1: builder ----
FROM python:3.12-slim AS builder
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Stage 2: runtime ----
FROM python:3.12-slim AS runtime
ENV PYTHONUNBUFFERED=1 PATH="/opt/venv/bin:$PATH"
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv      # bring ONLY the built venv across
COPY app/ .
USER appuser                                  # run as non-root
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys; \
    sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build it and compare sizes:

```bash
docker build -f dockerfiles/Dockerfile.multistage -t freelanceforge:prod .
docker images freelanceforge
```
```
REPOSITORY       TAG    IMAGE ID       SIZE
freelanceforge   prod   1111aaaa       190MB     <- runtime only
freelanceforge   dev    2222bbbb       210MB
```

The gap is small here because our deps are light, but the pattern is decisive when
you have build toolchains (gcc, node build steps, Go compilation): a Go binary
built in a 1GB stage can ship in a final image of a few MB.

## Three levers for smaller, safer images

**1. Start slimmer.** Base image choices, smallest to largest:

| Base | Size-ish | Trade-off |
|------|----------|-----------|
| `scratch` | ~0 | empty; only for static binaries (Go/Rust) |
| distroless | tiny | no shell/package manager (harder to debug, very secure) |
| `alpine` | ~5MB | musl libc — occasional Python wheel issues |
| `-slim` | ~80–130MB | Debian, broad compatibility — a safe default |
| full | ~1GB | everything; rarely needed in production |

**2. Ship without build tools.** The whole reason for the builder stage: compilers
and dev headers never reach the final image.

**3. Run as non-root.** `USER appuser` means a container breakout starts from an
unprivileged account, not root. This is a baseline security expectation for
production images — do it by default.

## Proof — no build tooling in the final image

```bash
docker run --rm freelanceforge:prod which gcc || echo "no gcc in final image ✓"
docker run --rm freelanceforge:prod whoami
```
```
no gcc in final image ✓
appuser
```

The runtime image has neither the compiler nor root — exactly what you want to
ship.

## Break it — the `COPY --from` that grabs too much

A multi-stage build only helps if the final stage copies **just** what it needs:

```dockerfile
# WRONG: drags the entire builder filesystem into the final image
COPY --from=builder / /
```

This copies caches, apt lists, and build tools right back in — defeating the whole
exercise, and often breaking the image. Copy **specific artifacts** (the venv, the
compiled binary, the built `dist/` folder), never the whole stage:

```dockerfile
COPY --from=builder /opt/venv /opt/venv     # right: only the built dependencies
```

**Lesson:** the value of multi-stage is in being *selective* about
`COPY --from`. If you copy everything, you've just added a stage for nothing.

## Exercises

1. Build both `freelanceforge:dev` and `freelanceforge:prod` and compare their
   sizes with `docker images`. Explain where the difference comes from.
2. Prove the production image runs as a non-root user and contains no compiler.
3. Swap the runtime base to `python:3.12-alpine`, rebuild, and note any changes in
   size or in whether the Python wheels install cleanly.

Solutions: [`solutions/09.md`](../../solutions/09.md)
