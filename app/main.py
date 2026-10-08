from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import settings
from app.routers import events
from app.services.db import ensure_tables


@asynccontextmanager
async def lifespan(app: FastAPI):
    ensure_tables()
    yield


app = FastAPI(
    title="CampusPulse 2026",
    description="Smart Campus Operations Platform — NorthBridge University",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(events.router)


@app.get("/health", tags=["meta"])
def health() -> dict:
    return {
        "status": "ok",
        "env": settings.app_env,
        "local_db": settings.use_local_db,
    }