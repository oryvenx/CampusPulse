"""
CampusPulse 2026 — FastAPI entrypoint.
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import alerts, auth, events


app = FastAPI(
    title="CampusPulse 2026",
    description="Smart Campus Operations Platform — NorthBridge University",
    version="0.2.0",
)

# All API routes live under /api/*  (CloudFront routes /api/* to this service)
app.include_router(auth.router, prefix="/api")
app.include_router(alerts.router, prefix="/api")
app.include_router(events.router, prefix="/api")


# ---------- Dashboard (local dev fallback) ----------
DASHBOARD_DIR = Path(__file__).resolve().parent.parent / "dashboard"

if DASHBOARD_DIR.exists() and (DASHBOARD_DIR / "dist").exists():
    app.mount("/static", StaticFiles(directory=str(DASHBOARD_DIR / "dist")), name="static")

    @app.get("/", include_in_schema=False)
    def dashboard_index():
        return FileResponse(str(DASHBOARD_DIR / "dist" / "index.html"))


@app.get("/api/health", tags=["meta"])
def health() -> dict:
    return {
        "status": "ok",
        "env": settings.app_env,
        "region": settings.aws_region,
    }