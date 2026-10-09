"""
CampusPulse 2026 — FastAPI entrypoint.
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.logging_config import configure_logging, get_logger
from app.middleware import RequestContextMiddleware
from app.routers import alerts, auth, events

configure_logging(level="INFO")
log = get_logger("app")

app = FastAPI(
    title="CampusPulse 2026",
    description="Smart Campus Operations Platform — NorthBridge University",
    version="0.3.0",
)

app.add_middleware(RequestContextMiddleware)

# All API routes under /api/*  (CloudFront routes /api/* here)
app.include_router(auth.router, prefix="/api")
app.include_router(alerts.router, prefix="/api")
app.include_router(events.router, prefix="/api")


DASHBOARD_DIR = Path(__file__).resolve().parent.parent / "dashboard"
if DASHBOARD_DIR.exists() and (DASHBOARD_DIR / "dist").exists():
    app.mount(
        "/static", StaticFiles(directory=str(DASHBOARD_DIR / "dist")), name="static"
    )

    @app.get("/", include_in_schema=False)
    def dashboard_index():
        return FileResponse(str(DASHBOARD_DIR / "dist" / "index.html"))


@app.on_event("startup")
def on_startup():
    log.info(
        "startup",
        env=settings.app_env,
        region=settings.aws_region,
        events_table=settings.events_table,
    )


@app.on_event("shutdown")
def on_shutdown():
    log.info("shutdown")


@app.get("/api/health", tags=["meta"])
def health() -> dict:
    return {
        "status": "ok",
        "env": settings.app_env,
        "region": settings.aws_region,
    }
