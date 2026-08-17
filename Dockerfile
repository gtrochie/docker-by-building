# syntax=docker/dockerfile:1
FROM python:3.12-slim

# Don't buffer stdout/stderr; don't write .pyc files.
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
