"""
CampusPulse 2026 — FastAPI entrypoint.
"""

from fastapi import FastAPI

from app.config import settings
from app.routers import events


app = FastAPI(
    title="CampusPulse 2026",
    description="Smart Campus Operations Platform — NorthBridge University",
    version="0.1.0",
)

app.include_router(events.router)


@app.get("/health", tags=["meta"])
def health() -> dict:
    return {
        "status": "ok",
        "env": settings.app_env,
        "region": settings.aws_region,
    }