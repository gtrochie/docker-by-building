"""FreelanceForge — a tiny quoting API used as the thing we containerize.

Deliberately small and dependency-light so image builds in the course are fast.
The database bits are lazy-imported so the app runs fine WITHOUT a database
(early modules) and gains a /db/ping endpoint once DATABASE_URL is set and
psycopg is installed (networking / compose modules).
"""
import os
from fastapi import FastAPI
from pydantic import BaseModel

VAT_RATE = float(os.getenv("VAT_RATE", "0.15"))  # SA standard VAT, override via env
APP_ENV = os.getenv("APP_ENV", "development")

app = FastAPI(title="FreelanceForge", version="1.0.0")


class Quote(BaseModel):
    items: list[float]
    vat_rate: float | None = None


@app.get("/")
def root():
    return {"app": "FreelanceForge", "env": APP_ENV, "vat_rate": VAT_RATE}


@app.get("/health")
def health():
    # Used by Docker HEALTHCHECK in later modules.
    return {"status": "ok"}


@app.post("/quote")
def quote(q: Quote):
    rate = q.vat_rate if q.vat_rate is not None else VAT_RATE
    subtotal = round(sum(q.items), 2)
    vat = round(subtotal * rate, 2)
    return {"subtotal": subtotal, "vat_rate": rate, "vat": vat, "total": round(subtotal + vat, 2)}


@app.get("/db/ping")
def db_ping():
    """Returns the Postgres version if DATABASE_URL is set and reachable.

    Lazy import so the app has no hard dependency on psycopg when run without a DB.
    """
    url = os.getenv("DATABASE_URL")
    if not url:
        return {"db": "not configured", "hint": "set DATABASE_URL"}
    try:
        import psycopg  # imported only when needed
        with psycopg.connect(url, connect_timeout=3) as conn:
            version = conn.execute("SELECT version()").fetchone()[0]
        return {"db": "ok", "version": version}
    except Exception as exc:  # noqa: BLE001 - surface the error to the caller
        return {"db": "error", "detail": str(exc)}
